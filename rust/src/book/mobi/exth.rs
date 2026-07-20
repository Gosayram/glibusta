use anyhow::Result;
use compact_str::CompactString;
use nom::IResult;
use nom::bytes::streaming::{tag, take};
use nom::error::{Error, ErrorKind};
use nom::multi::count;
use nom::number::streaming::be_u32;

use super::{MobiHeader, encoding};

/// ARC-2.2: CompactString for stack-allocated metadata strings.
pub(crate) struct MobiMetadata {
    pub title: Option<CompactString>,
    pub author: Option<CompactString>,
    pub language: Option<CompactString>,
    pub description: Option<CompactString>,
    pub cover_record_index: Option<u32>,
    /// PalmDB record containing the KF8 boundary marker (EXTH 121).
    /// The KF8 MOBI header, when present, is the following record.
    pub kf8_boundary_record_index: Option<u32>,
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
            kf8_boundary_record_index: None,
            has_exth: false,
        }
    }
}

// ---------------------------------------------------------------------------
// DEP-1.1: nom combinators for EXTH parsing
// ---------------------------------------------------------------------------

/// Parse EXTH header: "EXTH" + length(u32) + record_count(u32)
fn exth_header(input: &[u8]) -> IResult<&[u8], (u32, u32)> {
    let (input, _) = tag("EXTH".as_bytes())(input)?;
    let (input, length) = be_u32(input)?;
    let (input, count) = be_u32(input)?;
    Ok((input, (length, count)))
}

/// Parse a single EXTH record: type(u32) + size(u32) + data
fn exth_record(input: &[u8]) -> IResult<&[u8], (u32, Vec<u8>)> {
    let (input, rec_type) = be_u32(input)?;
    let (input, size) = be_u32(input)?;
    // size includes the 8-byte header (type + size)
    if size < 8 {
        return Err(nom::Err::Failure(Error::new(input, ErrorKind::Verify)));
    }
    let data_len = (size as usize).saturating_sub(8);
    let (input, data) = take(data_len)(input)?;
    Ok((input, (rec_type, data.to_vec())))
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

        let exth_data = &record0[exth_offset..];

        let (_remaining, (length, rec_count)) = match exth_header(exth_data) {
            Ok(r) => r,
            Err(_) => {
                return Ok(MobiMetadata {
                    has_exth: true,
                    ..MobiMetadata::default()
                });
            }
        };

        let Some(exth_end) = exth_offset.checked_add(length as usize) else {
            return Ok(MobiMetadata {
                has_exth: true,
                ..MobiMetadata::default()
            });
        };
        if length < 12 || exth_end > record0.len() {
            return Ok(MobiMetadata {
                has_exth: true,
                ..MobiMetadata::default()
            });
        }

        // Parse records after the 12-byte header (EXTH + length + count)
        let records_data = &record0[exth_offset + 12..exth_end];
        let max_record_count = records_data.len() / 8;
        if rec_count as usize > max_record_count {
            return Ok(MobiMetadata {
                has_exth: true,
                ..MobiMetadata::default()
            });
        }
        use nom::Parser;
        let (padding, records) = match count(exth_record, rec_count as usize).parse(records_data) {
            Ok(parsed) => parsed,
            Err(_) => {
                return Ok(MobiMetadata {
                    has_exth: true,
                    ..MobiMetadata::default()
                });
            }
        };
        // EXTH is 4-byte aligned. The bytes after declared records are only
        // alignment padding, never a hidden metadata record.
        if padding.len() > 3 || padding.iter().any(|&byte| byte != 0) {
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
        let mut kf8_boundary_record_index: Option<u32> = None;

        for (rec_type, data) in &records {
            match rec_type {
                100 => {
                    author = Some(
                        encoding::decode_text(data, header.text_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                503 => {
                    title = Some(
                        encoding::decode_text(data, header.text_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                524 => {
                    language = Some(
                        encoding::decode_text(data, header.text_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                103 => {
                    description = Some(
                        encoding::decode_text(data, header.text_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                201 if data.len() >= 4 => {
                    cover_record_index =
                        Some(u32::from_be_bytes([data[0], data[1], data[2], data[3]]));
                }
                121 if data.len() >= 4 => {
                    kf8_boundary_record_index =
                        Some(u32::from_be_bytes([data[0], data[1], data[2], data[3]]));
                }
                _ => {}
            }
        }

        Ok(MobiMetadata {
            title: title.map(CompactString::new),
            author: author.map(CompactString::new),
            language: language.map(CompactString::new),
            description: description.map(CompactString::new),
            cover_record_index,
            kf8_boundary_record_index,
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

#[cfg(test)]
mod tests {
    use super::{ExthParser, MobiHeader};

    fn exth_header() -> MobiHeader {
        MobiHeader {
            compression: 1,
            encryption_type: 0,
            text_length: 0,
            text_encoding: 1252,
            text_record_count: 0,
            record_size: 4096,
            full_name_offset: 0,
            full_name_length: 0,
            exth_flags: 0x40,
            first_image_record_index: 0,
            extra_data_flags: 0,
        }
    }

    #[test]
    fn rejects_exth_record_smaller_than_its_eight_byte_header() {
        let mut record0 = Vec::from(&b"EXTH"[..]);
        record0.extend_from_slice(&20u32.to_be_bytes());
        record0.extend_from_slice(&1u32.to_be_bytes());
        record0.extend_from_slice(&503u32.to_be_bytes());
        record0.extend_from_slice(&4u32.to_be_bytes());

        let metadata = ExthParser
            .parse(&record0, &exth_header())
            .expect("malformed optional EXTH metadata must not fail book parsing");

        assert!(metadata.has_exth);
        assert!(metadata.title.is_none());
    }

    #[test]
    fn accepts_zero_alignment_padding_and_rejects_non_padding_bytes() {
        let mut record0 = Vec::from(&b"EXTH"[..]);
        record0.extend_from_slice(&28u32.to_be_bytes());
        record0.extend_from_slice(&1u32.to_be_bytes());
        record0.extend_from_slice(&503u32.to_be_bytes());
        record0.extend_from_slice(&13u32.to_be_bytes());
        record0.extend_from_slice(b"Title");
        record0.extend_from_slice(&[0, 0, 0]);

        let metadata = ExthParser
            .parse(&record0, &exth_header())
            .expect("zero EXTH alignment padding must be accepted");
        assert_eq!(metadata.title.as_deref(), Some("Title"));

        let last_byte = record0.len() - 1;
        record0[last_byte] = 1;
        let malformed = ExthParser
            .parse(&record0, &exth_header())
            .expect("malformed optional EXTH metadata must not fail book parsing");
        assert!(malformed.has_exth);
        assert!(malformed.title.is_none());
    }
}
