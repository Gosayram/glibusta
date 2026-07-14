use std::cmp::Ordering;
use std::path::Path;

use anyhow::{Context, Result, bail};
use base64::Engine;
use base64::engine::general_purpose::STANDARD;
use unrar_ng::Archive;

use crate::api::models::{
    BlockType, BookFormat, MAX_COMPRESSION_RATIO, MAX_EXTRACTED_FILES, MAX_FILE_SIZE,
    MAX_IMAGE_SIZE, NormalizedBook, ReaderBlock, ReaderChapter,
};

const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff"];

/// Parse a CBR archive from its path. UnRAR can only operate on filesystem paths.
pub fn parse_cbr_path(path: &Path) -> Result<NormalizedBook> {
    let metadata = std::fs::metadata(path)
        .with_context(|| format!("Failed to read CBR file metadata: {}", path.display()))?;
    if metadata.len() > MAX_FILE_SIZE {
        bail!(
            "CBR exceeds maximum file size of {} MiB",
            MAX_FILE_SIZE / 1024 / 1024
        );
    }

    let mut archive = Archive::new(path)
        .open_for_processing()
        .with_context(|| format!("Failed to open CBR archive: {}", path.display()))?;
    let mut entry_count = 0usize;
    let mut total_uncompressed_size = 0u64;
    let mut images = Vec::new();

    loop {
        let Some(entry) = archive
            .read_header()
            .context("Failed to read CBR entry header")?
        else {
            break;
        };
        entry_count = entry_count.saturating_add(1);
        if entry_count > MAX_EXTRACTED_FILES {
            bail!(
                "CBR has too many entries: {} (max {})",
                entry_count,
                MAX_EXTRACTED_FILES
            );
        }

        let entry_name = entry.entry().filename.to_string_lossy().into_owned();
        let entry_size = entry.entry().unpacked_size;
        total_uncompressed_size = total_uncompressed_size
            .checked_add(entry_size)
            .context("CBR decompressed size overflow")?;
        if total_uncompressed_size > MAX_FILE_SIZE {
            bail!(
                "CBR exceeds maximum decompressed size of {} MiB",
                MAX_FILE_SIZE / 1024 / 1024
            );
        }
        if total_uncompressed_size > metadata.len().saturating_mul(MAX_COMPRESSION_RATIO) {
            bail!(
                "CBR exceeds maximum compression ratio of {}:1",
                MAX_COMPRESSION_RATIO
            );
        }

        let Some(media_type) = image_media_type(&entry_name).filter(|_| entry.entry().is_file())
        else {
            archive = entry.skip().context("Failed to skip CBR entry")?;
            continue;
        };
        if entry_size > MAX_IMAGE_SIZE as u64 {
            bail!(
                "CBR image '{}' exceeds maximum size of {} MiB",
                entry_name,
                MAX_IMAGE_SIZE / 1024 / 1024
            );
        }

        let (bytes, next_archive) = entry.read().context("Failed to extract CBR image")?;
        if bytes.len() > MAX_IMAGE_SIZE {
            bail!(
                "CBR image '{}' exceeds maximum size after extraction",
                entry_name
            );
        }
        images.push((entry_name, media_type, bytes));
        archive = next_archive;
    }

    if images.is_empty() {
        bail!("CBR archive contains no supported images");
    }
    images.sort_unstable_by(|left, right| natural_cmp(&left.0, &right.0));

    let blocks = images
        .into_iter()
        .enumerate()
        .map(|(index, (_, media_type, bytes))| ReaderBlock {
            index: index as i32,
            text: String::new(),
            block_type: BlockType::Image,
            image_url: Some(format!(
                "data:{media_type};base64,{}",
                STANDARD.encode(bytes)
            )),
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
        })
        .collect();

    let title = path
        .file_stem()
        .and_then(|name| name.to_str())
        .filter(|name| !name.trim().is_empty())
        .unwrap_or("CBR")
        .to_owned();

    Ok(NormalizedBook {
        id: crate::book::sha256_hex(path.as_os_str().as_encoded_bytes()),
        title,
        authors: Vec::new(),
        description: None,
        cover_url: None,
        chapters: vec![ReaderChapter {
            index: 0,
            title: "Pages".to_owned(),
            blocks,
        }],
        metadata: None,
        book_format: BookFormat::Cbr,
        language: None,
        warnings: Vec::new(),
        images: Vec::new(),
        toc: Vec::new(),
    })
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
    use super::{image_media_type, natural_cmp, parse_cbr_path};
    use std::cmp::Ordering;

    #[test]
    fn recognizes_supported_image_extensions_case_insensitively() {
        assert_eq!(image_media_type("pages/001.JPEG"), Some("image/jpeg"));
        assert_eq!(image_media_type("pages/002.webp"), Some("image/webp"));
        assert_eq!(image_media_type("notes.txt"), None);
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
    fn rejects_a_non_rar_file_without_crashing_the_native_parser() {
        let path =
            std::env::temp_dir().join(format!("glibusta-invalid-cbr-{}.cbr", uuid::Uuid::new_v4()));
        std::fs::write(&path, b"not a RAR archive").expect("write invalid CBR fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(result.is_err());
    }

    #[test]
    fn reads_a_rar4_archive_before_rejecting_non_image_contents() {
        // Minimal valid RAR4 archive from UnRAR's own test corpus. It contains
        // a VERSION file, so the CBR parser must scan it and then reject it for
        // having no image pages rather than treating RAR4 as an invalid format.
        const RAR4_ARCHIVE: &[u8] = &[
            0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0x00, 0xcf, 0x90, 0x73, 0x00, 0x00, 0x0d, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0x0c, 0x74, 0x20, 0x80, 0x27, 0x00, 0x15,
            0x00, 0x00, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x03, 0x45, 0xf3, 0x7d, 0xc6, 0xa4, 0x8a,
            0x07, 0x47, 0x1d, 0x33, 0x07, 0x00, 0xa4, 0x81, 0x00, 0x00, 0x56, 0x45, 0x52, 0x53,
            0x49, 0x4f, 0x4e, 0x0c, 0x00, 0x8f, 0xec, 0x8a, 0x45, 0xcc, 0x23, 0xc8, 0x48, 0x08,
            0x83, 0x62, 0xfe, 0x5f, 0xdd, 0x5c, 0x53, 0x88, 0xf0, 0x72, 0xc4, 0x3d, 0x7b, 0x00,
            0x40, 0x07, 0x00,
        ];
        let path =
            std::env::temp_dir().join(format!("glibusta-rar4-cbr-{}.cbr", uuid::Uuid::new_v4()));
        std::fs::write(&path, RAR4_ARCHIVE).expect("write RAR4 fixture");

        let result = parse_cbr_path(&path);
        let _ = std::fs::remove_file(path);

        assert!(matches!(result, Err(error) if error.to_string().contains("no supported images")));
    }
}
