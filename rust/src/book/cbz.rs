use std::cmp::Ordering;
use std::io::Read;
use std::path::Path;

use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use quick_xml::Reader;
use quick_xml::events::Event;
use sha2::{Digest, Sha256};
use zip::ZipArchive;

use crate::api::models::{
    BlockType, BookFormat, MAX_COMPRESSION_RATIO, MAX_EXTRACTED_FILES, MAX_FILE_SIZE,
    MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock, ReaderChapter,
};

const IMAGE_EXTENSIONS: &[&str] = &[
    "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "jxl", "avif",
];
const MAX_COMIC_INFO_BYTES: u64 = 1024 * 1024;

/// Parse a CBZ archive from its filesystem path.
pub fn parse_cbz_path(path: &Path) -> Result<NormalizedBook> {
    let metadata = std::fs::metadata(path)
        .with_context(|| format!("Failed to read CBZ file metadata: {}", path.display()))?;
    if metadata.len() > MAX_FILE_SIZE {
        bail!(
            "CBZ exceeds maximum file size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }
    let id = cbz_content_id(path)?;

    let file = std::fs::File::open(path)
        .with_context(|| format!("Failed to open CBZ file: {}", path.display()))?;
    let mut archive = ZipArchive::new(file)
        .with_context(|| format!("Failed to open CBZ archive: {}", path.display()))?;

    if archive.has_overlapping_files().unwrap_or(false) {
        bail!("CBZ archive contains overlapping files (potential zip bomb)");
    }

    let entry_count = archive.len();
    if entry_count > MAX_EXTRACTED_FILES {
        bail!(
            "CBZ has too many entries: {} (max {})",
            entry_count,
            MAX_EXTRACTED_FILES
        );
    }

    let mut total_uncompressed_size: u128 = 0;
    let mut image_entries: Vec<(String, &'static str)> = Vec::new();
    let mut comic_info: Option<ComicInfo> = None;

    for i in 0..entry_count {
        let entry = archive.by_index(i).context("Failed to read CBZ entry")?;
        let name = entry.name().to_string();
        let size = entry.size();
        let compressed = entry.compressed_size();

        total_uncompressed_size = total_uncompressed_size
            .checked_add(size as u128)
            .context("CBZ decompressed size overflow")?;
        if total_uncompressed_size > MAX_FILE_SIZE as u128 {
            bail!(
                "CBZ exceeds maximum decompressed size of {} MiB",
                MAX_FILE_SIZE / 1024 / 1024
            );
        }
        if size > 0
            && (compressed == 0
                || size as u128
                    > (compressed as u128).saturating_mul(MAX_COMPRESSION_RATIO as u128))
        {
            bail!(
                "CBZ entry '{}' exceeds maximum compression ratio of {}:1",
                name,
                MAX_COMPRESSION_RATIO
            );
        }

        let file_name = name.rsplit(['/', '\\']).next().unwrap_or(&name);
        if file_name.eq_ignore_ascii_case("ComicInfo.xml") && entry.is_file() {
            if size <= MAX_COMIC_INFO_BYTES {
                drop(entry);
                let mut entry = archive.by_index(i)?;
                let mut bytes = Vec::with_capacity(size as usize);
                entry.read_to_end(&mut bytes)?;
                comic_info = parse_comic_info(&bytes);
            }
            continue;
        }

        if !entry.is_file() {
            continue;
        }

        let path_parts: Vec<&str> = name.split('/').collect();
        if path_parts.contains(&"__MACOSX") || file_name.starts_with("._") {
            continue;
        }

        if let Some(media_type) = image_media_type(file_name) {
            if size > MAX_IMAGE_SIZE as u64 {
                bail!(
                    "CBZ image '{}' exceeds maximum size of {} MiB",
                    name,
                    MAX_IMAGE_SIZE / 1024 / 1024
                );
            }
            image_entries.push((name, media_type));
        }
    }

    if image_entries.is_empty() {
        bail!("CBZ archive contains no supported images");
    }
    image_entries.sort_unstable_by(|left, right| natural_cmp(&left.0, &right.0));

    let mut blocks = Vec::with_capacity(image_entries.len());
    for (index, (name, media_type)) in image_entries.iter().enumerate() {
        let mut entry = archive
            .by_name(name)
            .with_context(|| format!("Failed to read CBZ image '{}'", name))?;
        let mut bytes = Vec::with_capacity(entry.size() as usize);
        entry
            .read_to_end(&mut bytes)
            .with_context(|| format!("Failed to extract CBZ image '{}'", name))?;

        let image_url = if index == 0 {
            Some(format!(
                "data:{media_type};base64,{}",
                STANDARD.encode(&bytes)
            ))
        } else {
            Some(name.clone())
        };

        blocks.push(ReaderBlock {
            index: index as i32,
            text: String::new(),
            block_type: BlockType::Image,
            image_url,
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
            page_break_before: false,
            page_break_inside_avoid: false,
            has_drop_cap: false,
        });
    }

    let cover_url = blocks
        .first()
        .and_then(|block| block.image_url.clone())
        .filter(|url| url.starts_with("data:"));

    let fallback_title = path
        .file_stem()
        .and_then(|name| name.to_str())
        .filter(|name| !name.trim().is_empty())
        .unwrap_or("CBZ");
    let title = comic_info
        .as_ref()
        .and_then(|info| info.title.clone())
        .unwrap_or_else(|| fallback_title.to_owned());
    let authors = comic_info
        .as_ref()
        .and_then(|info| info.authors.clone())
        .unwrap_or_default();
    let comic_metadata = comic_info.as_ref().and_then(ComicInfo::metadata);

    Ok(NormalizedBook {
        id,
        title,
        authors,
        description: None,
        cover_url,
        chapters: vec![ReaderChapter {
            index: 0,
            title: "Pages".to_owned(),
            blocks,
        }],
        metadata: comic_metadata,
        metadata_json: None,
        book_format: BookFormat::Cbz,
        language: None,
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
}

fn cbz_content_id(path: &Path) -> Result<String> {
    let mut file = std::fs::File::open(path)
        .with_context(|| format!("Failed to open CBZ for hashing: {}", path.display()))?;
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; 64 * 1024];

    loop {
        let read = file
            .read(&mut buffer)
            .with_context(|| format!("Failed to read CBZ for hashing: {}", path.display()))?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }

    Ok(format!("{:x}", hasher.finalize()))
}

#[derive(Default)]
struct ComicInfo {
    title: Option<String>,
    authors: Option<Vec<String>>,
    series: Option<String>,
    number: Option<String>,
}

impl ComicInfo {
    fn metadata(&self) -> Option<serde_json::Value> {
        let mut metadata = serde_json::Map::new();
        if let Some(series) = &self.series {
            metadata.insert(
                "series".to_owned(),
                serde_json::Value::String(series.clone()),
            );
        }
        if let Some(number) = &self.number {
            metadata.insert(
                "number".to_owned(),
                serde_json::Value::String(number.clone()),
            );
        }
        (!metadata.is_empty()).then_some(serde_json::Value::Object(metadata))
    }
}

fn parse_comic_info(bytes: &[u8]) -> Option<ComicInfo> {
    let text = decode_comic_info(bytes)?;
    let mut reader = Reader::from_str(&text);
    reader.config_mut().trim_text(true);
    let mut info = ComicInfo::default();
    let mut field = None;

    loop {
        match reader.read_event() {
            Ok(Event::Eof) => break,
            Ok(Event::Start(element)) => {
                field = match element.local_name().as_ref() {
                    b"Title" => Some("title"),
                    b"Writer" => Some("writer"),
                    b"Series" => Some("series"),
                    b"Number" => Some("number"),
                    _ => None,
                };
            }
            Ok(Event::Text(value)) => {
                let value = value.xml10_content().ok()?.trim().to_owned();
                if value.is_empty() {
                    continue;
                }
                match field {
                    Some("title") => info.title = Some(value),
                    Some("writer") => {
                        let authors = value
                            .split([',', ';'])
                            .map(str::trim)
                            .filter(|author| !author.is_empty())
                            .map(str::to_owned)
                            .collect::<Vec<_>>();
                        if !authors.is_empty() {
                            info.authors = Some(authors);
                        }
                    }
                    Some("series") => info.series = Some(value),
                    Some("number") => info.number = Some(value),
                    _ => {}
                }
            }
            Ok(Event::End(_)) => field = None,
            Err(_) => return None,
            _ => {}
        }
    }

    Some(info)
}

fn decode_comic_info(bytes: &[u8]) -> Option<String> {
    let (bytes, big_endian) = match bytes {
        [0xFF, 0xFE, rest @ ..] => (rest, false),
        [0xFE, 0xFF, rest @ ..] => (rest, true),
        _ => {
            // Try UTF-8 first
            if let Ok(s) = std::str::from_utf8(bytes) {
                return Some(s.to_owned());
            }
            // Try encoding from XML declaration: <?xml ... encoding="..." ?>
            let header_len = bytes.len().min(256);
            let header = &bytes[..header_len];
            if let Some(encoding) = detect_xml_encoding(header) {
                let (decoded, _, _) = encoding.decode(bytes);
                return Some(decoded.into_owned());
            }
            return None;
        }
    };
    if bytes.len() % 2 != 0 {
        return None;
    }
    let code_units = bytes
        .chunks_exact(2)
        .map(|pair| {
            if big_endian {
                u16::from_be_bytes([pair[0], pair[1]])
            } else {
                u16::from_le_bytes([pair[0], pair[1]])
            }
        })
        .collect::<Vec<_>>();
    String::from_utf16(&code_units).ok()
}

fn detect_xml_encoding(header: &[u8]) -> Option<&'static encoding_rs::Encoding> {
    // Search raw bytes for encoding="..." — the keyword is always ASCII
    let lower_header: Vec<u8> = header.iter().map(|b| b.to_ascii_lowercase()).collect();
    let needle = b"encoding=";
    let start = lower_header.windows(needle.len()).position(|w| w == needle)?;
    let key_end = start + needle.len();
    if key_end >= header.len() {
        return None;
    }
    let quote = header[key_end];
    if quote != b'"' && quote != b'\'' {
        return None;
    }
    let value_start = key_end + 1;
    let value_end = header[value_start..]
        .iter()
        .position(|&b| b == quote)?
        + value_start;
    let encoding_name = &header[value_start..value_end];
    encoding_rs::Encoding::for_label(encoding_name)
}

fn image_media_type(path: &str) -> Option<&'static str> {
    let extension = path.rsplit_once('.')?.1.to_ascii_lowercase();
    if !IMAGE_EXTENSIONS.contains(&extension.as_str()) {
        return None;
    }
    Some(match extension.as_str() {
        "jpg" | "jpeg" => "image/jpeg",
        "png" => "image/png",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "bmp" => "image/bmp",
        "tiff" => "image/tiff",
        "jxl" => "image/jxl",
        "avif" => "image/avif",
        _ => unreachable!("extension was checked against IMAGE_EXTENSIONS"),
    })
}

fn natural_cmp(left: &str, right: &str) -> Ordering {
    let left = left.as_bytes();
    let right = right.as_bytes();
    let (mut left_index, mut right_index) = (0, 0);

    while left_index < left.len() && right_index < right.len() {
        let left_digit = left[left_index].is_ascii_digit();
        let right_digit = right[right_index].is_ascii_digit();
        if left_digit && right_digit {
            let left_start = left_index;
            let right_start = right_index;
            while left_index < left.len() && left[left_index].is_ascii_digit() {
                left_index += 1;
            }
            while right_index < right.len() && right[right_index].is_ascii_digit() {
                right_index += 1;
            }
            let left_number = trim_leading_zeroes(&left[left_start..left_index]);
            let right_number = trim_leading_zeroes(&right[right_start..right_index]);
            let ordering = left_number
                .len()
                .cmp(&right_number.len())
                .then_with(|| left_number.cmp(right_number))
                .then_with(|| (left_index - left_start).cmp(&(right_index - right_start)));
            if ordering != Ordering::Equal {
                return ordering;
            }
        } else {
            let ordering = left[left_index]
                .to_ascii_lowercase()
                .cmp(&right[right_index].to_ascii_lowercase());
            if ordering != Ordering::Equal {
                return ordering;
            }
            left_index += 1;
            right_index += 1;
        }
    }

    left.len().cmp(&right.len())
}

fn trim_leading_zeroes(number: &[u8]) -> &[u8] {
    let first_non_zero = number
        .iter()
        .position(|byte| *byte != b'0')
        .unwrap_or(number.len().saturating_sub(1));
    &number[first_non_zero..]
}

#[cfg(test)]
mod tests {
    use super::{cbz_content_id, image_media_type, natural_cmp, parse_cbz_path, parse_comic_info};
    use crate::api::models::BlockType;
    use std::cmp::Ordering;
    use std::io::Write;
    use std::path::PathBuf;

    fn create_cbz_fixture(name: &str, entries: &[(&str, &[u8])]) -> PathBuf {
        let path =
            std::env::temp_dir().join(format!("glibusta-{}-{}.cbz", name, uuid::Uuid::new_v4()));
        let file = std::fs::File::create(&path).expect("create CBZ fixture");
        let mut writer = zip::ZipWriter::new(file);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        for (entry_name, data) in entries {
            writer
                .start_file(*entry_name, options)
                .expect("start CBZ entry");
            writer.write_all(data).expect("write CBZ entry");
        }
        writer.finish().expect("finish CBZ archive");
        path
    }

    #[test]
    fn recognizes_supported_image_extensions_case_insensitively() {
        assert_eq!(image_media_type("pages/001.JPEG"), Some("image/jpeg"));
        assert_eq!(image_media_type("pages/002.webp"), Some("image/webp"));
        assert_eq!(image_media_type("notes.txt"), None);
        assert_eq!(image_media_type("pages/003.jxl"), Some("image/jxl"));
        assert_eq!(image_media_type("pages/004.avif"), Some("image/avif"));
    }

    #[test]
    fn sorts_page_names_naturally() {
        assert_eq!(natural_cmp("pages/2.jpg", "pages/10.jpg"), Ordering::Less);
        assert_eq!(
            natural_cmp("pages/001.jpg", "pages/1.jpg"),
            Ordering::Greater
        );
    }

    #[test]
    fn parses_comic_info_metadata() {
        let info = parse_comic_info(
            br#"<ComicInfo><Title>Comic</Title><Writer>A; B</Writer><Series>Series</Series><Number>7</Number></ComicInfo>"#,
        )
        .expect("parse ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Comic"));
        assert_eq!(
            info.authors.as_deref(),
            Some(["A".to_string(), "B".to_string()].as_slice())
        );
        assert_eq!(
            info.metadata(),
            Some(serde_json::json!({"series": "Series", "number": "7"}))
        );
    }

    #[test]
    fn parses_utf16le_comic_info_metadata() {
        let xml = "<ComicInfo><Title>Комикс</Title><Writer>Автор</Writer></ComicInfo>";
        let mut bytes = vec![0xFF, 0xFE];
        bytes.extend(xml.encode_utf16().flat_map(u16::to_le_bytes));

        let info = parse_comic_info(&bytes).expect("parse UTF-16 ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Комикс"));
        assert_eq!(
            info.authors.as_deref(),
            Some([String::from("Автор")].as_slice())
        );
    }

    #[test]
    fn parses_utf16be_comic_info_metadata() {
        let xml = "<ComicInfo><Title>Comic</Title></ComicInfo>";
        let mut bytes = vec![0xFE, 0xFF];
        bytes.extend(xml.encode_utf16().flat_map(u16::to_be_bytes));

        let info = parse_comic_info(&bytes).expect("parse UTF-16 ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Comic"));
    }

    #[test]
    fn parses_utf8_bom_comic_info_metadata() {
        let bytes = b"\xEF\xBB\xBF<ComicInfo><Title>\xD0\x9A\xD0\xBE\xD0\xBC\xD0\xB8\xD0\xBA\xD1\x81</Title><Writer>\xD0\x90\xD0\xB2\xD1\x82\xD0\xBE\xD1\x80</Writer></ComicInfo>";

        let info = parse_comic_info(bytes).expect("parse UTF-8 BOM ComicInfo.xml");

        assert_eq!(info.title.as_deref(), Some("Комикс"));
        assert_eq!(
            info.authors.as_deref(),
            Some([String::from("Автор")].as_slice())
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "ZipArchive uses std::fs::File which Miri cannot execute"
    )]
    fn parses_a_cbz_with_two_images() {
        let path = create_cbz_fixture(
            "two-images",
            &[
                ("001.jpg", b"fake-jpeg-data"),
                ("002.png", b"fake-png-data"),
            ],
        );

        let result = parse_cbz_path(&path);
        let _ = std::fs::remove_file(&path);

        let book = result.expect("parse two-image CBZ");
        assert!(book.title.contains("two-images"));
        assert_eq!(book.chapters.len(), 1);
        assert_eq!(book.chapters[0].blocks.len(), 2);
        assert_eq!(book.chapters[0].blocks[0].block_type, BlockType::Image);
        assert!(
            book.chapters[0].blocks[0]
                .image_url
                .as_ref()
                .is_some_and(|url| url.starts_with("data:image/jpeg;base64,"))
        );
        assert_eq!(
            book.chapters[0].blocks[1].image_url.as_deref(),
            Some("002.png")
        );
        assert!(
            book.cover_url
                .as_ref()
                .is_some_and(|url| url.starts_with("data:"))
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "ZipArchive uses std::fs::File which Miri cannot execute"
    )]
    fn extracts_comicinfo_from_cbz() {
        let comic_info = br#"<ComicInfo><Title>Test Comic</Title><Writer>Author A, Author B</Writer></ComicInfo>"#;
        let path = create_cbz_fixture(
            "with-comicinfo",
            &[
                ("ComicInfo.xml", comic_info.as_slice()),
                ("page1.jpg", b"jpeg-data"),
            ],
        );

        let result = parse_cbz_path(&path);
        let _ = std::fs::remove_file(&path);

        let book = result.expect("parse CBZ with ComicInfo");
        assert_eq!(book.title, "Test Comic");
        assert_eq!(book.authors, ["Author A", "Author B"]);
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "ZipArchive uses std::fs::File which Miri cannot execute"
    )]
    fn rejects_cbz_without_images() {
        let path = create_cbz_fixture(
            "no-images",
            &[("readme.txt", b"This archive has no images")],
        );

        let result = parse_cbz_path(&path);
        let _ = std::fs::remove_file(&path);

        assert!(result.is_err());
        assert!(
            result
                .unwrap_err()
                .to_string()
                .contains("no supported images")
        );
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "ZipArchive uses std::fs::File which Miri cannot execute"
    )]
    fn rejects_non_zip_file() {
        let path =
            std::env::temp_dir().join(format!("glibusta-invalid-cbz-{}.cbz", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"not a ZIP archive").expect("write invalid CBZ fixture");

        let result = parse_cbz_path(&path);
        let _ = std::fs::remove_file(&path);

        assert!(result.is_err());
    }

    #[test]
    fn derives_cbz_id_from_contents() {
        let directory =
            std::env::temp_dir().join(format!("glibusta-cbz-id-{}", uuid::Uuid::new_v4()));
        std::fs::create_dir_all(&directory).expect("create CBZ id test directory");
        let first = directory.join("first.cbz");
        let second = directory.join("second.cbz");
        std::fs::write(&first, b"same archive contents").expect("write first CBZ");
        std::fs::write(&second, b"same archive contents").expect("write second CBZ");

        let first_id = cbz_content_id(&first).expect("hash first CBZ");
        let second_id = cbz_content_id(&second).expect("hash second CBZ");
        std::fs::write(&second, b"replaced archive contents").expect("replace second CBZ");
        let replaced_id = cbz_content_id(&second).expect("hash replaced CBZ");
        let _ = std::fs::remove_dir_all(directory);

        assert_eq!(first_id, second_id);
        assert_ne!(first_id, replaced_id);
        assert_eq!(first_id.len(), 64);
    }
}
