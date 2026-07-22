use anyhow::Result;
use compact_str::CompactString;
use nom::IResult;
use nom::bytes::streaming::{tag, take};
use nom::error::{Error, ErrorKind};
use nom::multi::count;
use nom::number::streaming::be_u32;

use super::{MobiHeader, encoding};

/// EXTH records are optional metadata.  Keep a corrupt record-0 from making
/// the parser materialize an unbounded number of tiny records.
const MAX_EXTH_RECORDS: usize = 4096;

/// ARC-2.2: CompactString for stack-allocated metadata strings.
pub(crate) struct MobiMetadata {
    pub title: Option<CompactString>,
    pub authors: Vec<CompactString>,
    pub publisher: Option<CompactString>,
    pub isbn: Option<CompactString>,
    pub subjects: Vec<CompactString>,
    pub language: Option<CompactString>,
    pub description: Option<CompactString>,
    pub fixed_layout: bool,
    pub book_type: Option<CompactString>,
    pub orientation_lock: Option<CompactString>,
    pub resource_count: Option<u32>,
    pub original_resolution: Option<CompactString>,
    pub zero_gutter: bool,
    pub zero_margin: bool,
    pub metadata_resource_uri: Option<CompactString>,
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
            authors: Vec::new(),
            publisher: None,
            isbn: None,
            subjects: Vec::new(),
            language: None,
            description: None,
            fixed_layout: false,
            book_type: None,
            orientation_lock: None,
            resource_count: None,
            original_resolution: None,
            zero_gutter: false,
            zero_margin: false,
            metadata_resource_uri: None,
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
    pub fn parse(
        &self,
        record0: &[u8],
        header: &MobiHeader,
        forced_encoding: Option<&str>,
    ) -> Result<MobiMetadata> {
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
        if rec_count as usize > max_record_count || rec_count as usize > MAX_EXTH_RECORDS {
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
        let mut authors: Vec<String> = Vec::new();
        let mut publisher: Option<String> = None;
        let mut isbn: Option<String> = None;
        let mut subjects: Vec<String> = Vec::new();
        let mut language: Option<String> = None;
        let mut description: Option<String> = None;
        let mut fixed_layout = false;
        let mut book_type: Option<String> = None;
        let mut orientation_lock: Option<String> = None;
        let mut resource_count: Option<u32> = None;
        let mut original_resolution: Option<String> = None;
        let mut zero_gutter = false;
        let mut zero_margin = false;
        let mut metadata_resource_uri: Option<String> = None;
        let mut cover_record_index: Option<u32> = None;
        let mut kf8_boundary_record_index: Option<u32> = None;

        for (rec_type, data) in &records {
            match rec_type {
                100 => {
                    let value = encoding::decode_text(data, header.text_encoding, forced_encoding)
                        .trim()
                        .to_string();
                    if !value.is_empty() {
                        authors.push(value);
                    }
                }
                101 => {
                    let value = encoding::decode_text(data, header.text_encoding, forced_encoding)
                        .trim()
                        .to_string();
                    if !value.is_empty() {
                        publisher = Some(value);
                    }
                }
                503 => {
                    title = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                524 => {
                    language = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                103 => {
                    description = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                104 => {
                    let value = encoding::decode_text(data, header.text_encoding, forced_encoding)
                        .trim()
                        .to_string();
                    if !value.is_empty() {
                        isbn = Some(value);
                    }
                }
                105 => {
                    let value = encoding::decode_text(data, header.text_encoding, forced_encoding)
                        .trim()
                        .to_string();
                    if !value.is_empty() {
                        subjects.push(value);
                    }
                }
                122 => {
                    fixed_layout =
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .eq_ignore_ascii_case("true");
                }
                123 => {
                    book_type = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                124 => {
                    orientation_lock = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                125 if data.len() == 4 => {
                    resource_count = Some(u32::from_be_bytes([data[0], data[1], data[2], data[3]]));
                }
                126 => {
                    original_resolution = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .to_string(),
                    );
                }
                127 => {
                    zero_gutter =
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .eq_ignore_ascii_case("true");
                }
                128 => {
                    zero_margin =
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
                            .trim()
                            .eq_ignore_ascii_case("true");
                }
                129 => {
                    metadata_resource_uri = Some(
                        encoding::decode_text(data, header.text_encoding, forced_encoding)
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
            authors: authors.into_iter().map(CompactString::new).collect(),
            publisher: publisher.map(CompactString::new),
            isbn: isbn.map(CompactString::new),
            subjects: subjects.into_iter().map(CompactString::new).collect(),
            language: language.map(CompactString::new),
            description: description.map(CompactString::new),
            fixed_layout,
            book_type: book_type.map(CompactString::new),
            orientation_lock: orientation_lock.map(CompactString::new),
            resource_count,
            original_resolution: original_resolution.map(CompactString::new),
            zero_gutter,
            zero_margin,
            metadata_resource_uri: metadata_resource_uri.map(CompactString::new),
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
    use super::{ExthParser, MAX_EXTH_RECORDS, MobiHeader};

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
            locale: None,
            input_language: None,
            output_language: None,
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
            .parse(&record0, &exth_header(), None)
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
            .parse(&record0, &exth_header(), None)
            .expect("zero EXTH alignment padding must be accepted");
        assert_eq!(metadata.title.as_deref(), Some("Title"));

        let last_byte = record0.len() - 1;
        record0[last_byte] = 1;
        let malformed = ExthParser
            .parse(&record0, &exth_header(), None)
            .expect("malformed optional EXTH metadata must not fail book parsing");
        assert!(malformed.has_exth);
        assert!(malformed.title.is_none());
    }

    #[test]
    fn rejects_record_data_that_exceeds_the_declared_exth_bounds() {
        let mut record0 = Vec::from(&b"EXTH"[..]);
        record0.extend_from_slice(&20u32.to_be_bytes());
        record0.extend_from_slice(&1u32.to_be_bytes());
        record0.extend_from_slice(&100u32.to_be_bytes());
        record0.extend_from_slice(&12u32.to_be_bytes());

        let metadata = ExthParser
            .parse(&record0, &exth_header(), None)
            .expect("malformed optional EXTH metadata must not fail book parsing");

        assert!(metadata.has_exth);
        assert!(metadata.authors.is_empty());
    }

    #[test]
    fn rejects_excessive_but_in_bounds_record_count_before_materializing_records() {
        let record_count = (MAX_EXTH_RECORDS + 1) as u32;
        let mut record0 = Vec::from(&b"EXTH"[..]);
        record0.extend_from_slice(&(12_u32 + record_count * 8).to_be_bytes());
        record0.extend_from_slice(&record_count.to_be_bytes());
        // The first entry would otherwise set a title, while the remaining
        // zero-length entries make the declared count structurally valid.
        record0.extend_from_slice(&503u32.to_be_bytes());
        record0.extend_from_slice(&8u32.to_be_bytes());
        for _ in 1..record_count {
            record0.extend_from_slice(&0u32.to_be_bytes());
            record0.extend_from_slice(&8u32.to_be_bytes());
        }

        let metadata = ExthParser
            .parse(&record0, &exth_header(), None)
            .expect("excessive optional EXTH metadata must not fail book parsing");

        assert!(metadata.has_exth);
        assert!(metadata.title.is_none());
    }
}
