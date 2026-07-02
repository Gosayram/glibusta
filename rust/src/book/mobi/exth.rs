use anyhow::Result;

use super::{BinaryReader, MobiHeader};

pub(crate) struct MobiMetadata {
    pub title: Option<String>,
    pub author: Option<String>,
    pub language: Option<String>,
    pub description: Option<String>,
    pub cover_record_index: Option<u32>,
    pub has_exth: bool,
}

impl MobiMetadata {
    pub fn default() -> Self {
        Self {
            title: None,
            author: None,
            language: None,
            description: None,
            cover_record_index: None,
            has_exth: false,
        }
    }
}

pub(crate) struct ExthParser;

impl ExthParser {
    pub fn parse(&self, record0: &[u8], header: &MobiHeader) -> Result<MobiMetadata> {
        if (header.exth_flags & 0x40) == 0 {
            return Ok(MobiMetadata::default());
        }

        let exth_offset = match self.find_exth_offset(record0) {
            Some(o) => o,
            None => return Ok(MobiMetadata::default()),
        };

        let reader = BinaryReader::new(record0);
        let length = reader.u32be(exth_offset + 4)? as usize;
        let count = reader.u32be(exth_offset + 8)? as usize;
        let exth_end = exth_offset + length;

        if length < 12 || exth_end > record0.len() {
            return Ok(MobiMetadata {
                has_exth: true,
                ..MobiMetadata::default()
            });
        }

        let mut title: Option<String> = None;
        let mut author: Option<String> = None;
        let mut language: Option<String> = None;
        let mut description: Option<String> = None;
        let mut cover_record_index: Option<u32> = None;
        let mut pos = exth_offset + 12;

        for _ in 0..count {
            if pos + 8 > exth_end {
                break;
            }
            let r = BinaryReader::new(record0);
            let rec_type = r.u32be(pos)?;
            let size = r.u32be(pos + 4)? as usize;
            if size < 8 || pos + size > exth_end {
                break;
            }

            let data = &record0[pos + 8..pos + size];
            match rec_type {
                100 => {
                    author = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                503 => {
                    title = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                524 => {
                    language = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                103 => {
                    description = Some(String::from_utf8_lossy(data).trim().to_string());
                }
                201 if data.len() >= 4 => {
                    let cr = BinaryReader::new(data);
                    cover_record_index = Some(cr.u32be(0)?);
                }
                _ => {}
            }
            pos += size;
        }

        Ok(MobiMetadata {
            title,
            author,
            language,
            description,
            cover_record_index,
            has_exth: true,
        })
    }

    fn find_exth_offset(&self, record0: &[u8]) -> Option<usize> {
        (0..record0.len().saturating_sub(3)).find(|&i| {
            record0[i] == 0x45
                && record0[i + 1] == 0x58
                && record0[i + 2] == 0x54
                && record0[i + 3] == 0x48
        })
    }
}
