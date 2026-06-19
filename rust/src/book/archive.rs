use anyhow::{Context, Result};
use std::collections::HashMap;
use std::io::Read;
use zip::ZipArchive;

pub struct ZipEntry {
    pub name: String,
    pub content: Vec<u8>,
}

pub struct ZipFile {
    entries: HashMap<String, Vec<u8>>,
    entry_names: Vec<String>,
}

impl ZipFile {
    pub fn open(bytes: &[u8]) -> Result<Self> {
        let cursor = std::io::Cursor::new(bytes);
        let mut archive =
            ZipArchive::new(cursor).context("Failed to open ZIP archive")?;
        let mut entries = HashMap::new();
        let mut entry_names = Vec::new();

        for i in 0..archive.len() {
            let mut file = archive.by_index(i).context("Failed to read ZIP entry")?;
            let name = file.name().to_string();
            let mut content = Vec::new();
            file.read_to_end(&mut content)
                .context("Failed to read ZIP entry content")?;
            entry_names.push(name.clone());
            entries.insert(name, content);
        }

        Ok(Self {
            entries,
            entry_names,
        })
    }

    pub fn find_file(&self, name: &str) -> Option<&[u8]> {
        self.entries.get(name).map(|v| v.as_slice())
    }

    pub fn find_file_case_insensitive(&self, name: &str) -> Option<&[u8]> {
        let lower = name.to_lowercase();
        self.entries
            .iter()
            .find(|(k, _)| k.to_lowercase() == lower)
            .map(|(_, v)| v.as_slice())
    }

    pub fn find_file_flexible(&self, name: &str) -> Option<&[u8]> {
        self.find_file(name)
            .or_else(|| self.find_file_case_insensitive(name))
    }

    pub fn entry_names(&self) -> &[String] {
        &self.entry_names
    }

    pub fn entry_count(&self) -> usize {
        self.entries.len()
    }
}

pub fn decode_zip(bytes: &[u8]) -> Result<ZipFile> {
    ZipFile::open(bytes)
}
