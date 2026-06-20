use anyhow::{Context, Result};
use std::io::Cursor;
use std::io::Read;
use zip::ZipArchive;

const MAX_DECOMPRESSED_SIZE: u128 = 100 * 1024 * 1024; // 100MB

pub struct ZipFile {
    archive: ZipArchive<Cursor<Vec<u8>>>,
    entry_names: Vec<String>,
}

impl ZipFile {
    pub fn open(bytes: &[u8]) -> Result<Self> {
        let cursor = Cursor::new(bytes.to_vec());
        let mut archive = ZipArchive::new(cursor).context("Failed to open ZIP archive")?;

        // Reject zip bombs with overlapping file entries
        if archive.has_overlapping_files().unwrap_or(false) {
            anyhow::bail!("ZIP archive contains overlapping files (potential zip bomb)");
        }

        // Reject archives exceeding safe decompressed size
        let mut total_size: u128 = 0;
        let mut entry_names = Vec::new();
        for i in 0..archive.len() {
            let file = archive.by_index(i).context("Failed to read ZIP entry")?;
            let name = file.name().to_string();
            let size = file.size();
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

    pub fn find_file(&mut self, name: &str) -> Option<Vec<u8>> {
        let mut file = self.archive.by_name(name).ok()?;
        let mut content = Vec::new();
        file.read_to_end(&mut content).ok()?;
        Some(content)
    }

    pub fn find_file_case_insensitive(&mut self, name: &str) -> Option<Vec<u8>> {
        let lower = name.to_lowercase();
        let entry = self
            .entry_names
            .iter()
            .find(|n| n.to_lowercase() == lower)?
            .clone();
        self.find_file(&entry)
    }

    pub fn find_file_flexible(&mut self, name: &str) -> Option<Vec<u8>> {
        self.find_file(name)
            .or_else(|| self.find_file_case_insensitive(name))
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

pub fn decode_zip(bytes: &[u8]) -> Result<ZipFile> {
    ZipFile::open(bytes)
}
