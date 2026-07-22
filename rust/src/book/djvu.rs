use crate::api::models::{
    BlockType, MAX_CHAPTER_SIZE, MAX_FILE_SIZE, NormalizedBook, ReaderBlock, ReaderChapter,
    RichSpan, TocEntry,
};
use anyhow::{Context, Result, bail};
use crc32fast::Hasher as Crc32;
use djvu_rs::DjVuDocument;
use djvu_rs::djvu_render::{RenderOptions, render_pixmap};
use flate2::Compression;
use flate2::write::ZlibEncoder;
use std::io::Write;

pub struct DjvuEngine;

// These limits are deliberately checked on the IFF framing before `djvu-rs`
// builds its chunk vectors or attempts image/text decoding.  They bound the
// document shapes accepted by the portable reader; native DjVuLibre support is
// intentionally out of scope for this parser.
const MAX_DJVU_COMPONENTS: usize = 4096;
const MAX_DJVU_PAGE_DIMENSION: u32 = 32_768;
const MAX_DJVU_PAGE_PIXELS: u64 = 100_000_000;

fn read_u32(bytes: &[u8]) -> Result<usize> {
    let array: [u8; 4] = bytes
        .try_into()
        .map_err(|_| anyhow::anyhow!("truncated DjVu IFF length"))?;
    Ok(u32::from_be_bytes(array) as usize)
}

/// Visits an IFF body without allocating a chunk vector.
fn visit_iff_chunks(
    mut body: &[u8],
    chunk_count: &mut usize,
    mut visitor: impl FnMut([u8; 4], &[u8], &mut usize) -> Result<()>,
) -> Result<()> {
    while !body.is_empty() {
        // IFF aligns chunks to an even boundary.  A single zero padding byte is
        // allowed at the end; any other short tail is malformed framing.
        if body.len() == 1 && body[0] == 0 {
            return Ok(());
        }
        if body.len() < 8 {
            bail!("truncated DjVu IFF chunk header");
        }

        *chunk_count = chunk_count
            .checked_add(1)
            .ok_or_else(|| anyhow::anyhow!("DjVu IFF chunk count overflow"))?;
        if *chunk_count > MAX_DJVU_COMPONENTS {
            bail!("DjVu document contains too many IFF components");
        }

        let id: [u8; 4] = body[..4]
            .try_into()
            .map_err(|_| anyhow::anyhow!("truncated DjVu IFF chunk id"))?;
        let data_len = read_u32(&body[4..8])?;
        let data_end = 8usize
            .checked_add(data_len)
            .ok_or_else(|| anyhow::anyhow!("DjVu IFF chunk length overflow"))?;
        if data_end > body.len() {
            bail!("DjVu IFF chunk extends beyond its container");
        }

        visitor(id, &body[8..data_end], chunk_count)?;
        let padded_end = data_end
            .checked_add(data_len & 1)
            .ok_or_else(|| anyhow::anyhow!("DjVu IFF padding overflow"))?;
        if padded_end > body.len() {
            bail!("truncated DjVu IFF chunk padding");
        }
        body = &body[padded_end..];
    }
    Ok(())
}

fn validate_page_chunks(body: &[u8], chunk_count: &mut usize) -> Result<()> {
    let mut info_count = 0usize;
    visit_iff_chunks(body, chunk_count, |id, data, _| {
        if (id == *b"TXTa" || id == *b"TXTz" || id == *b"ANTa" || id == *b"ANTz")
            && data.len() > MAX_CHAPTER_SIZE
        {
            bail!("DjVu text or annotation chunk exceeds the supported size");
        }
        if id == *b"INFO" {
            info_count += 1;
            if data.len() < 4 {
                bail!("DjVu INFO chunk is truncated");
            }
            let width = u16::from_be_bytes([data[0], data[1]]) as u32;
            let height = u16::from_be_bytes([data[2], data[3]]) as u32;
            let pixels = u64::from(width) * u64::from(height);
            if width == 0
                || height == 0
                || width > MAX_DJVU_PAGE_DIMENSION
                || height > MAX_DJVU_PAGE_DIMENSION
                || pixels > MAX_DJVU_PAGE_PIXELS
            {
                bail!("DjVu page dimensions exceed the supported limits");
            }
        }
        Ok(())
    })?;
    if info_count != 1 {
        bail!("DjVu page must contain exactly one INFO chunk");
    }
    Ok(())
}

/// Reject malformed or unsupported document shapes before the dependency
/// allocates per-component state.  Indirect DJVM documents stay unsupported:
/// this byte-only API never resolves document-provided names to the filesystem
/// or network.
fn validate_djvu_container(bytes: &[u8]) -> Result<()> {
    if bytes.len() as u64 > MAX_FILE_SIZE {
        bail!("DjVu file exceeds the supported size");
    }
    if bytes.len() < 16 || &bytes[..4] != b"AT&T" || &bytes[4..8] != b"FORM" {
        bail!("invalid DjVu IFF header");
    }
    let form_len = read_u32(&bytes[8..12])?;
    let form_end = 12usize
        .checked_add(form_len)
        .ok_or_else(|| anyhow::anyhow!("DjVu FORM length overflow"))?;
    if form_len < 4 || form_end > bytes.len() {
        bail!("DjVu FORM extends beyond the input");
    }

    let form_type: [u8; 4] = bytes[12..16]
        .try_into()
        .map_err(|_| anyhow::anyhow!("truncated DjVu FORM type"))?;
    let body = &bytes[16..form_end];
    let mut chunk_count = 0usize;
    match &form_type {
        b"DJVU" => validate_page_chunks(body, &mut chunk_count),
        b"DJVM" => {
            let mut dirm_count = 0usize;
            let mut bundled_components = None;
            let mut form_count = 0usize;
            visit_iff_chunks(body, &mut chunk_count, |id, data, chunk_count| {
                if id == *b"DIRM" {
                    dirm_count += 1;
                    if data.len() < 3 {
                        bail!("DjVu DIRM chunk is truncated");
                    }
                    let component_count = u16::from_be_bytes([data[1], data[2]]) as usize;
                    if component_count > MAX_DJVU_COMPONENTS {
                        bail!("DjVu DIRM declares too many components");
                    }
                    if data[0] & 0x80 == 0 {
                        bail!("indirect DjVu documents are not supported");
                    }
                    let offset_bytes = component_count
                        .checked_mul(4)
                        .ok_or_else(|| anyhow::anyhow!("DjVu DIRM offset overflow"))?;
                    if match 3usize.checked_add(offset_bytes) {
                        Some(end) => end > data.len(),
                        None => true,
                    } {
                        bail!("DjVu DIRM offset table is truncated");
                    }
                    bundled_components = Some(component_count);
                } else if id == *b"FORM" {
                    form_count += 1;
                    if data.len() < 4 {
                        bail!("truncated embedded DjVu FORM");
                    }
                    let embedded_type: [u8; 4] = data[..4]
                        .try_into()
                        .map_err(|_| anyhow::anyhow!("truncated embedded DjVu FORM type"))?;
                    if embedded_type == *b"DJVU" {
                        validate_page_chunks(&data[4..], chunk_count)?;
                    } else if embedded_type != *b"DJVI" && embedded_type != *b"THUM" {
                        bail!("unsupported embedded DjVu FORM type");
                    }
                }
                Ok(())
            })?;
            if dirm_count != 1 {
                bail!("DjVu DJVM must contain exactly one DIRM chunk");
            }
            if bundled_components != Some(form_count) {
                bail!("DjVu DIRM component count does not match bundled FORMs");
            }
            Ok(())
        }
        _ => bail!("unsupported DjVu FORM type"),
    }
}

fn parse_document(bytes: &[u8]) -> Result<DjVuDocument> {
    validate_djvu_container(bytes)?;
    DjVuDocument::parse(bytes).context("Failed to parse DjVu document")
}

fn encode_png(data: &[u8], width: u32, height: u32) -> Result<Vec<u8>> {
    let mut out = Vec::new();
    out.extend_from_slice(b"\x89PNG\r\n\x1a\n");
    let mut ihdr = Vec::new();
    ihdr.extend_from_slice(&width.to_be_bytes());
    ihdr.extend_from_slice(&height.to_be_bytes());
    ihdr.extend_from_slice(&[8, 6, 0, 0, 0]);
    write_chunk(&mut out, b"IHDR", &ihdr);
    let mut raw = Vec::with_capacity(data.len() + height as usize);
    for row in data.chunks(width as usize * 4) {
        raw.push(0);
        raw.extend_from_slice(row);
    }
    let mut z = ZlibEncoder::new(Vec::new(), Compression::fast());
    z.write_all(&raw)?;
    let compressed = z.finish()?;
    write_chunk(&mut out, b"IDAT", &compressed);
    write_chunk(&mut out, b"IEND", &[]);

    Ok(out)
}

fn write_chunk(out: &mut Vec<u8>, typ: &[u8; 4], data: &[u8]) {
    let len = data.len() as u32;
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(typ);
    let mut crc = Crc32::new();
    crc.update(typ);
    crc.update(data);
    out.extend_from_slice(data);
    out.extend_from_slice(&crc.finalize().to_be_bytes());
}

impl DjvuEngine {
    pub fn render_page_to_png(bytes: &[u8], page_index: usize, max_width: u16) -> Result<Vec<u8>> {
        let doc = parse_document(bytes)?;
        let page = doc
            .page(page_index)
            .context(format!("Page {} not found", page_index))?;
        let viewport = (max_width as u32).min(1080);
        let opts = RenderOptions::fit_to_width(page, viewport);
        let pixmap = render_pixmap(page, &opts).context("Failed to render DjVu page")?;
        encode_png(&pixmap.data, pixmap.width, pixmap.height)
    }

    pub fn extract_text(bytes: &[u8]) -> Result<String> {
        let doc = parse_document(bytes)?;
        let mut text = String::new();
        for i in 0..doc.page_count() {
            let page = doc.page(i).context("Failed to access DjVu page")?;
            if let Some(page_text) = page.text().context("Failed to decode DjVu text layer")?
                && !page_text.trim().is_empty()
            {
                text.push_str(&page_text);
                text.push('\n');
            }
        }
        Ok(text)
    }

    pub fn page_count(bytes: &[u8]) -> Result<i32> {
        let doc = parse_document(bytes)?;
        Ok(doc.page_count() as i32)
    }

    pub fn parse_djvu(bytes: &[u8]) -> Result<NormalizedBook> {
        let doc = parse_document(bytes)?;
        let page_count = doc.page_count();
        let mut chapters = Vec::new();
        for i in 0..page_count {
            let page = doc.page(i).context(format!("Failed to get page {}", i))?;
            let page_text = page
                .text()
                .context("Failed to decode DjVu text layer")?
                .unwrap_or_default();
            let blocks = if page_text.trim().is_empty() {
                vec![ReaderBlock {
                    index: 0,
                    block_type: BlockType::Image,
                    text: format!("[Страница {} — DjVu изображение]", i + 1),
                    image_url: None,
                    note_ref: None,
                    rich_spans: None,
                    heading_level: None,
                    ordered: None,
                    list_items: None,
                    table_rows: None,
                    image_alt: None,
                    text_indent: None,
                    text_align: None,
                    note_id: None,
                }]
            } else {
                page_text
                    .lines()
                    .enumerate()
                    .filter(|(_, line)| !line.trim().is_empty())
                    .map(|(idx, line)| ReaderBlock {
                        index: idx as i32,
                        block_type: BlockType::Paragraph,
                        text: line.trim().to_string(),
                        image_url: None,
                        note_ref: None,
                        rich_spans: Some(vec![RichSpan {
                            text: line.trim().to_string(),
                            bold: false,
                            italic: false,
                            superscript: false,
                            subscript: false,
                            strikethrough: false,
                            code: false,
                            style_name: None,
                            href: None,
                            line_break: false,
                        }]),
                        heading_level: None,
                        ordered: None,
                        list_items: None,
                        table_rows: None,
                        image_alt: None,
                        text_indent: None,
                        text_align: None,
                        note_id: None,
                    })
                    .collect()
            };
            chapters.push(ReaderChapter {
                index: i as i32,
                title: format!("Страница {}", i + 1),
                blocks,
            });
        }
        let toc: Vec<TocEntry> = chapters
            .iter()
            .map(|c| TocEntry {
                title: c.title.clone(),
                chapter_index: c.index,
                children: Vec::new(),
            })
            .collect();
        Ok(NormalizedBook {
            id: String::new(),
            title: "DjVu document".to_string(),
            authors: Vec::new(),
            description: None,
            cover_url: None,
            chapters,
            toc,
            book_format: crate::api::models::BookFormat::Djvu,
            warnings: Vec::new(),
            metadata: None,
            language: None,
            images: Vec::new(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::DjvuEngine;
    use std::panic::{AssertUnwindSafe, catch_unwind};

    fn chunk(id: &[u8; 4], data: &[u8]) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(8 + data.len() + (data.len() & 1));
        bytes.extend_from_slice(id);
        bytes.extend_from_slice(&(data.len() as u32).to_be_bytes());
        bytes.extend_from_slice(data);
        if data.len() & 1 == 1 {
            bytes.push(0);
        }
        bytes
    }

    fn form(form_type: &[u8; 4], chunks: &[Vec<u8>]) -> Vec<u8> {
        let body_len = 4 + chunks.iter().map(Vec::len).sum::<usize>();
        let mut bytes = Vec::with_capacity(12 + body_len);
        bytes.extend_from_slice(b"AT&TFORM");
        bytes.extend_from_slice(&(body_len as u32).to_be_bytes());
        bytes.extend_from_slice(form_type);
        for child in chunks {
            bytes.extend_from_slice(child);
        }
        bytes
    }

    fn info(width: u16, height: u16) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(10);
        bytes.extend_from_slice(&width.to_be_bytes());
        bytes.extend_from_slice(&height.to_be_bytes());
        bytes.extend_from_slice(&[0, 0, 0x2c, 0x01, 0x16, 0]);
        bytes
    }

    #[test]
    fn iff_admission_accepts_minimal_page_and_rejects_bad_lengths_without_panicking() {
        let valid = form(b"DJVU", &[chunk(b"INFO", &info(4, 4))]);
        assert_eq!(DjvuEngine::page_count(&valid).unwrap(), 1);

        let mut truncated = valid;
        truncated[8..12].copy_from_slice(&u32::MAX.to_be_bytes());
        let result = catch_unwind(AssertUnwindSafe(|| DjvuEngine::page_count(&truncated)));
        assert!(result.is_ok(), "malformed IFF must not panic");
        assert!(result.unwrap().is_err(), "truncated FORM must be rejected");
    }

    #[test]
    fn page_admission_rejects_duplicate_info_and_unsafe_dimensions() {
        let duplicate_info = form(
            b"DJVU",
            &[chunk(b"INFO", &info(4, 4)), chunk(b"INFO", &info(4, 4))],
        );
        assert!(
            DjvuEngine::page_count(&duplicate_info)
                .expect_err("duplicate INFO must not be accepted")
                .to_string()
                .contains("exactly one INFO")
        );

        let oversized = form(b"DJVU", &[chunk(b"INFO", &info(u16::MAX, u16::MAX))]);
        assert!(
            DjvuEngine::render_page_to_png(&oversized, 0, 1080)
                .expect_err("unsafe dimensions must be rejected before render")
                .to_string()
                .contains("dimensions")
        );
    }

    #[test]
    fn djvm_admission_rejects_indirect_and_inconsistent_bundled_metadata() {
        let indirect = form(b"DJVM", &[chunk(b"DIRM", &[0, 0, 1])]);
        assert!(
            DjvuEngine::page_count(&indirect)
                .expect_err("the byte-only reader must not resolve indirect documents")
                .to_string()
                .contains("indirect")
        );

        let bundled_without_component = form(b"DJVM", &[chunk(b"DIRM", &[0x80, 0, 1, 0, 0, 0, 0])]);
        assert!(
            DjvuEngine::page_count(&bundled_without_component)
                .expect_err("DIRM must describe exactly the bundled FORMs")
                .to_string()
                .contains("component count")
        );
    }
}
