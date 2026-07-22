use crate::api::models::MAX_IMAGE_SIZE;

use super::{MobiHeader, MobiMetadata, PalmDb};

pub(crate) struct MobiCoverExtractor;

impl MobiCoverExtractor {
    pub fn extract(
        &self,
        full_bytes: &[u8],
        palm_db: &PalmDb,
        header: &MobiHeader,
        metadata: &MobiMetadata,
    ) -> Option<Vec<u8>> {
        let declared_cover = self.find_cover_record_index(header, metadata);
        if let Some(record_index) = declared_cover {
            // EXTH 201 is optional metadata and may point to a stale or
            // non-image record. Prefer it when valid, but never accept a
            // candidate without an image signature.
            if let Some(bytes) = self.safe_record_bytes(full_bytes, palm_db, record_index) {
                if let Some(image) = self.validate_image_bytes(bytes) {
                    return Some(image);
                }
            }
        }

        let first_image = (header.first_image_record_index > 0)
            .then_some(header.first_image_record_index as usize)?;
        // MOBI producers occasionally leave stale cover metadata or place a
        // thumbnail/non-image placeholder at the first image record. Scan the
        // resource tail for the first supported image instead of giving up on
        // the whole cover. This only inspects record slices and clones the
        // selected image after the size/signature checks.
        for record_index in first_image..palm_db.records.len() {
            if declared_cover == Some(record_index) {
                continue;
            }
            let Some(bytes) = self.safe_record_bytes(full_bytes, palm_db, record_index) else {
                continue;
            };
            if let Some(image) = self.validate_image_bytes(bytes) {
                return Some(image);
            }
        }

        None
    }

    fn find_cover_record_index(
        &self,
        header: &MobiHeader,
        metadata: &MobiMetadata,
    ) -> Option<usize> {
        if let Some(offset) = metadata.cover_record_index {
            if header.first_image_record_index > 0 {
                if let Some(index) = header.first_image_record_index.checked_add(offset) {
                    return Some(index as usize);
                }
            }
        }
        if header.first_image_record_index > 0 {
            return Some(header.first_image_record_index as usize);
        }
        None
    }

    fn safe_record_bytes<'a>(
        &self,
        full_bytes: &'a [u8],
        palm_db: &PalmDb,
        index: usize,
    ) -> Option<&'a [u8]> {
        if index >= palm_db.records.len() {
            return None;
        }
        let start = palm_db.records[index].offset;
        let end = if index + 1 < palm_db.records.len() {
            palm_db.records[index + 1].offset
        } else {
            full_bytes.len()
        };
        if start >= end || end > full_bytes.len() {
            return None;
        }
        Some(&full_bytes[start..end])
    }

    fn validate_image_bytes(&self, bytes: &[u8]) -> Option<Vec<u8>> {
        if bytes.len() > MAX_IMAGE_SIZE {
            return None;
        }
        if self.is_jpeg(bytes) || self.is_png(bytes) || self.is_gif(bytes) {
            Some(bytes.to_vec())
        } else {
            None
        }
    }

    fn is_jpeg(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8
    }

    fn is_png(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 4
            && bytes[0] == 0x89
            && bytes[1] == 0x50
            && bytes[2] == 0x4E
            && bytes[3] == 0x47
    }

    fn is_gif(&self, bytes: &[u8]) -> bool {
        bytes.len() >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46
    }
}

#[cfg(test)]
mod tests {
    use super::MobiCoverExtractor;
    use crate::book::mobi::{MobiHeader, MobiMetadata, PalmDb, PalmRecord};

    #[test]
    fn exth_cover_offset_is_relative_to_first_image_record() {
        let bytes = [
            [0_u8; 8].as_slice(),
            b"notimage".as_slice(),
            b"\x89PNG\r\n\x1a\n".as_slice(),
        ]
        .concat();
        let palm_db = PalmDb {
            name: String::new(),
            records: vec![
                PalmRecord {
                    offset: 0,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 8,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 16,
                    attributes: 0,
                    unique_id: 0,
                },
            ],
        };
        let header = MobiHeader {
            compression: 1,
            encryption_type: 0,
            text_length: 0,
            text_encoding: 0,
            text_record_count: 0,
            record_size: 0,
            full_name_offset: 0,
            full_name_length: 0,
            locale: None,
            input_language: None,
            output_language: None,
            exth_flags: 0,
            first_image_record_index: 1,
            extra_data_flags: 0,
        };
        let mut metadata = MobiMetadata::default();
        metadata.cover_record_index = Some(1);

        let cover = MobiCoverExtractor
            .extract(&bytes, &palm_db, &header, &metadata)
            .expect("cover image at first_image_record_index + EXTH offset");

        assert_eq!(cover, b"\x89PNG\r\n\x1a\n");
    }

    #[test]
    fn falls_back_to_first_image_when_declared_cover_is_not_an_image() {
        let bytes = [
            [0_u8; 8].as_slice(),
            b"\xff\xd8cover".as_slice(),
            b"not an image".as_slice(),
        ]
        .concat();
        let palm_db = PalmDb {
            name: String::new(),
            records: vec![
                PalmRecord {
                    offset: 0,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 8,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 15,
                    attributes: 0,
                    unique_id: 0,
                },
            ],
        };
        let header = MobiHeader {
            compression: 1,
            encryption_type: 0,
            text_length: 0,
            text_encoding: 0,
            text_record_count: 0,
            record_size: 0,
            full_name_offset: 0,
            full_name_length: 0,
            locale: None,
            input_language: None,
            output_language: None,
            exth_flags: 0,
            first_image_record_index: 1,
            extra_data_flags: 0,
        };
        let mut metadata = MobiMetadata::default();
        metadata.cover_record_index = Some(1);

        let cover = MobiCoverExtractor
            .extract(&bytes, &palm_db, &header, &metadata)
            .expect("safe first-image fallback");

        assert_eq!(cover, b"\xff\xd8cover");
    }

    #[test]
    fn falls_back_to_later_image_when_first_image_record_is_not_renderable() {
        let bytes = [
            [0_u8; 8].as_slice(),
            b"thumbnail placeholder".as_slice(),
            b"not an image either".as_slice(),
            b"GIF89a cover".as_slice(),
        ]
        .concat();
        let palm_db = PalmDb {
            name: String::new(),
            records: vec![
                PalmRecord {
                    offset: 0,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 8,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 29,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 48,
                    attributes: 0,
                    unique_id: 0,
                },
            ],
        };
        let header = MobiHeader {
            compression: 1,
            encryption_type: 0,
            text_length: 0,
            text_encoding: 0,
            text_record_count: 0,
            record_size: 0,
            full_name_offset: 0,
            full_name_length: 0,
            locale: None,
            input_language: None,
            output_language: None,
            exth_flags: 0,
            first_image_record_index: 1,
            extra_data_flags: 0,
        };
        let mut metadata = MobiMetadata::default();
        metadata.cover_record_index = Some(1);

        let cover = MobiCoverExtractor
            .extract(&bytes, &palm_db, &header, &metadata)
            .expect("later valid image must be used after stale cover records");

        assert_eq!(cover, b"GIF89a cover");
    }

    #[test]
    fn rejects_non_image_cover_candidates() {
        let bytes = [[0_u8; 8].as_slice(), b"plain text".as_slice()].concat();
        let palm_db = PalmDb {
            name: String::new(),
            records: vec![
                PalmRecord {
                    offset: 0,
                    attributes: 0,
                    unique_id: 0,
                },
                PalmRecord {
                    offset: 8,
                    attributes: 0,
                    unique_id: 0,
                },
            ],
        };
        let header = MobiHeader {
            compression: 1,
            encryption_type: 0,
            text_length: 0,
            text_encoding: 0,
            text_record_count: 0,
            record_size: 0,
            full_name_offset: 0,
            full_name_length: 0,
            locale: None,
            input_language: None,
            output_language: None,
            exth_flags: 0,
            first_image_record_index: 1,
            extra_data_flags: 0,
        };

        assert!(
            MobiCoverExtractor
                .extract(&bytes, &palm_db, &header, &MobiMetadata::default())
                .is_none()
        );
    }
}
