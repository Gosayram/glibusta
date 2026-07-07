use crate::api::models::{
    BlockType, NormalizedBook, ReaderBlock, ReaderChapter, RichSpan, TocEntry,
};
use anyhow::{Context, Result};
use crc32fast::Hasher as Crc32;
use djvu_rs::DjVuDocument;
use djvu_rs::djvu_render::{RenderOptions, render_pixmap};
use flate2::Compression;
use flate2::write::ZlibEncoder;
use std::io::Write;

pub struct DjvuEngine;

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
        let doc = DjVuDocument::parse(bytes).context("Failed to parse DjVu document")?;
        let page = doc
            .page(page_index)
            .context(format!("Page {} not found", page_index))?;
        let viewport = (max_width as u32).min(1080);
        let opts = RenderOptions::fit_to_width(page, viewport);
        let pixmap = render_pixmap(page, &opts).context("Failed to render DjVu page")?;
        encode_png(&pixmap.data, pixmap.width, pixmap.height)
    }

    pub fn extract_text(bytes: &[u8]) -> Result<String> {
        let doc = DjVuDocument::parse(bytes).context("Failed to parse DjVu document")?;
        let mut text = String::new();
        for i in 0..doc.page_count() {
            if let Ok(page) = doc.page(i) {
                if let Ok(Some(page_text)) = page.text() {
                    if !page_text.trim().is_empty() {
                        text.push_str(&page_text);
                        text.push('\n');
                    }
                }
            }
        }
        Ok(text)
    }

    pub fn page_count(bytes: &[u8]) -> Result<i32> {
        let doc = DjVuDocument::parse(bytes).context("Failed to parse DjVu document")?;
        Ok(doc.page_count() as i32)
    }

    pub fn parse_djvu(bytes: &[u8]) -> Result<NormalizedBook> {
        let doc = DjVuDocument::parse(bytes).context("Failed to parse DjVu document")?;
        let page_count = doc.page_count();
        let mut chapters = Vec::new();
        for i in 0..page_count {
            let page = doc.page(i).context(format!("Failed to get page {}", i))?;
            let page_text = page.text().ok().flatten().unwrap_or_default();
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
