use crate::api::models::{
    MAX_CHAPTER_SIZE, MAX_COMPRESSION_RATIO, MAX_EXTRACTED_FILES, MAX_FILE_SIZE,
};
use anyhow::{Context, Result};
use std::io::Cursor;
use std::io::Read;
use zip::ZipArchive;

const MAX_DECOMPRESSED_SIZE: u128 = 100 * 1024 * 1024; // 100MB

pub struct ZipFile<'a> {
    archive: ZipArchive<Cursor<&'a [u8]>>,
    entry_names: Vec<String>,
}

impl<'a> ZipFile<'a> {
    pub fn open(bytes: &'a [u8]) -> Result<Self> {
        if bytes.len() as u64 > MAX_FILE_SIZE {
            anyhow::bail!(
                "ZIP archive exceeds maximum file size ({}MB)",
                MAX_FILE_SIZE / 1024 / 1024
            );
        }
        let cursor = Cursor::new(bytes);
        let mut archive = ZipArchive::new(cursor).context("Failed to open ZIP archive")?;

        // Reject zip bombs with overlapping file entries
        if archive.has_overlapping_files().unwrap_or(false) {
            anyhow::bail!("ZIP archive contains overlapping files (potential zip bomb)");
        }

        // Reject archives exceeding safe decompressed size
        let mut total_size: u128 = 0;
        let mut entry_names = Vec::new();
        if archive.len() > MAX_EXTRACTED_FILES {
            anyhow::bail!(
                "ZIP archive has too many entries: {} (max {})",
                archive.len(),
                MAX_EXTRACTED_FILES
            );
        }
        for i in 0..archive.len() {
            let file = archive.by_index(i).context("Failed to read ZIP entry")?;
            let name = file.name().to_string();
            let size = file.size();
            let compressed_size = file.compressed_size();
            if size > 0
                && (compressed_size == 0
                    || size > compressed_size.saturating_mul(MAX_COMPRESSION_RATIO))
            {
                anyhow::bail!(
                    "ZIP entry '{}' exceeds maximum compression ratio of {}:1",
                    name,
                    MAX_COMPRESSION_RATIO
                );
            }
            total_size += size as u128;
            if total_size > MAX_DECOMPRESSED_SIZE {
                anyhow::bail!(
                    "ZIP archive exceeds maximum decompressed size ({}MB)",
                    MAX_DECOMPRESSED_SIZE / 1024 / 1024
                );
            }
            entry_names.push(name);
        }

        Ok(Self {
            archive,
            entry_names,
        })
    }

    /// Read a text-like entry using the default chapter-size limit.
    ///
    /// A missing entry is represented by `Ok(None)`; extraction and safety
    /// failures remain errors so callers cannot mistake them for absence.
    pub fn find_file(&mut self, name: &str) -> Result<Option<Vec<u8>>> {
        self.read_file_limited(name, MAX_CHAPTER_SIZE)
    }

    /// Read an archive entry after enforcing its caller-specific size limit.
    ///
    /// The size is validated from ZIP metadata before allocating the output
    /// buffer, so a malformed entry cannot force an unbounded extraction.
    pub fn read_file_limited(&mut self, name: &str, max_size: usize) -> Result<Option<Vec<u8>>> {
        let Ok(mut file) = self.archive.by_name(name) else {
            return Ok(None);
        };
        let size = usize::try_from(file.size()).context("ZIP entry size does not fit usize")?;
        if size > max_size {
            anyhow::bail!(
                "ZIP entry '{}' exceeds maximum size ({} bytes, max {} bytes)",
                name,
                size,
                max_size
            );
        }
        let mut content = Vec::with_capacity(size);
        let read_limit = match u64::try_from(max_size) {
            Ok(limit) => limit.saturating_add(1),
            Err(_) => u64::MAX,
        };
        file.by_ref()
            .take(read_limit)
            .read_to_end(&mut content)
            .context("Failed to extract ZIP entry")?;
        if content.len() > max_size {
            anyhow::bail!(
                "ZIP entry '{}' exceeds maximum size after extraction (max {} bytes)",
                name,
                max_size
            );
        }
        Ok(Some(content))
    }

    pub fn find_file_case_insensitive(&mut self, name: &str) -> Result<Option<Vec<u8>>> {
        let lower = name.to_lowercase();
        let Some(entry) = self
            .entry_names
            .iter()
            .find(|n| n.to_lowercase() == lower)
            .cloned()
        else {
            return Ok(None);
        };
        self.find_file(&entry)
    }

    pub fn find_file_flexible(&mut self, name: &str) -> Result<Option<Vec<u8>>> {
        if let Some(content) = self.find_file(name)? {
            return Ok(Some(content));
        }
        self.find_file_case_insensitive(name)
    }

    pub fn has_entry(&self, name: &str) -> bool {
        self.entry_names.iter().any(|n| n == name)
    }

    pub fn entry_names(&self) -> &[String] {
        &self.entry_names
    }

    pub fn entry_count(&self) -> usize {
        self.entry_names.len()
    }
}

pub fn decode_zip(bytes: &[u8]) -> Result<ZipFile<'_>> {
    ZipFile::open(bytes)
}

#[cfg(test)]
mod tests {
    use super::ZipFile;
    use std::io::{Cursor, Write};

    fn write_u16(bytes: &mut Vec<u8>, value: u16) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn write_u32(bytes: &mut Vec<u8>, value: u32) {
        bytes.extend_from_slice(&value.to_le_bytes());
    }

    fn single_entry_zip_fixture(
        name: &[u8],
        compression_method: u16,
        payload: &[u8],
        compressed_size: u32,
        uncompressed_size: u32,
    ) -> Vec<u8> {
        let mut bytes = Vec::new();

        // Local file header.
        write_u32(&mut bytes, 0x0403_4b50);
        write_u16(&mut bytes, 20);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, compression_method);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u32(&mut bytes, 0);
        write_u32(&mut bytes, compressed_size);
        write_u32(&mut bytes, uncompressed_size);
        write_u16(&mut bytes, name.len() as u16);
        write_u16(&mut bytes, 0);
        bytes.extend_from_slice(name);
        bytes.extend_from_slice(payload);

        let central_directory_offset = bytes.len() as u32;
        write_u32(&mut bytes, 0x0201_4b50);
        write_u16(&mut bytes, 20);
        write_u16(&mut bytes, 20);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, compression_method);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u32(&mut bytes, 0);
        write_u32(&mut bytes, compressed_size);
        write_u32(&mut bytes, uncompressed_size);
        write_u16(&mut bytes, name.len() as u16);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u32(&mut bytes, 0);
        write_u32(&mut bytes, 0);
        bytes.extend_from_slice(name);

        let central_directory_size = bytes.len() as u32 - central_directory_offset;
        write_u32(&mut bytes, 0x0605_4b50);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 0);
        write_u16(&mut bytes, 1);
        write_u16(&mut bytes, 1);
        write_u32(&mut bytes, central_directory_size);
        write_u32(&mut bytes, central_directory_offset);
        write_u16(&mut bytes, 0);
        bytes
    }

    /// A minimal deflated ZIP entry whose central-directory metadata declares
    /// a high compression ratio. `ZipFile::open` rejects it before attempting
    /// decompression, so the payload need not be a valid DEFLATE stream.
    fn highly_compressed_zip_fixture() -> Vec<u8> {
        single_entry_zip_fixture(b"chapter.xhtml", 8, &[0], 1, 32 * 1024)
    }

    #[test]
    fn rejects_entry_above_requested_read_limit() {
        let mut bytes = Cursor::new(Vec::new());
        let mut writer = zip::ZipWriter::new(&mut bytes);
        writer
            .start_file(
                "chapter.xhtml",
                zip::write::FileOptions::<()>::default()
                    .compression_method(zip::CompressionMethod::Stored),
            )
            .expect("start archive entry");
        writer.write_all(b"too large").expect("write archive entry");
        writer.finish().expect("finish archive");

        let archive_bytes = bytes.into_inner();
        let mut zip = ZipFile::open(&archive_bytes).expect("open archive");
        let error = zip
            .read_file_limited("chapter.xhtml", 1)
            .expect_err("entry must exceed the caller's limit");
        assert!(error.to_string().contains("exceeds maximum size"));
    }

    #[test]
    fn rejects_highly_compressed_entry_before_extraction() {
        let error = match ZipFile::open(&highly_compressed_zip_fixture()) {
            Ok(_) => panic!("archive must exceed ratio"),
            Err(error) => error,
        };
        assert!(error.to_string().contains("compression ratio"));
    }

    #[test]
    fn rejects_entry_that_exceeds_limit_during_extraction() {
        let bytes = single_entry_zip_fixture(b"chapter.xhtml", 0, b"ab", 2, 1);
        let mut zip = ZipFile::open(&bytes).expect("open archive");

        let error = zip
            .read_file_limited("chapter.xhtml", 1)
            .expect_err("extracted bytes must respect the caller limit");

        assert!(error.to_string().contains("after extraction"));
    }
}
