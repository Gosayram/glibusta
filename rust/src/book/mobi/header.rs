use anyhow::{Result, bail};

use super::BinaryReader;

pub(crate) struct MobiHeader {
    pub compression: u16,
    pub encryption_type: u16,
    pub text_length: u32,
    pub text_encoding: u16,
    pub text_record_count: u16,
    #[allow(dead_code)]
    pub record_size: u16,
    pub full_name_offset: u32,
    pub full_name_length: u32,
    pub exth_flags: u32,
    pub first_image_record_index: u32,
}

pub(crate) struct MobiHeaderParser;

impl MobiHeaderParser {
    const MOBI_OFFSET: usize = 16;
    const MIN_HEADER_LENGTH: usize = 16;
    const FULL_NAME_END: usize = 92;
    const FIRST_IMAGE_RECORD_END: usize = 112;
    const EXTH_FLAGS_END: usize = 132;

    pub fn parse(&self, record0: &[u8]) -> Result<MobiHeader> {
        let reader = BinaryReader::new(record0);
        let mobi_offset = Self::MOBI_OFFSET;

        if reader.ascii(mobi_offset, 4)? != "MOBI" {
            bail!("Invalid MOBI header");
        }

        let header_length = reader.u32be(mobi_offset + 4)? as usize;
        let Some(header_end) = mobi_offset.checked_add(header_length) else {
            bail!("MOBI header length overflows record 0");
        };
        if header_length < Self::MIN_HEADER_LENGTH || header_end > record0.len() {
            bail!("MOBI header length exceeds record 0");
        }

        // Fields introduced after the original MOBI header are optional.  Do
        // not reinterpret trailing record data as header fields when an older
        // variable-length header ends before them.
        let (full_name_offset, full_name_length) = if header_length >= Self::FULL_NAME_END {
            (
                reader.u32be(mobi_offset + 84)?,
                reader.u32be(mobi_offset + 88)?,
            )
        } else {
            (0, 0)
        };
        let first_image_record_index = if header_length >= Self::FIRST_IMAGE_RECORD_END {
            reader.u32be(mobi_offset + 108)?
        } else {
            0
        };
        let exth_flags = if header_length >= Self::EXTH_FLAGS_END {
            reader.u32be(mobi_offset + 128)?
        } else {
            0
        };

        Ok(MobiHeader {
            compression: reader.u16be(0)?,
            encryption_type: reader.u16be(12)?,
            text_length: reader.u32be(4)?,
            text_encoding: reader.u16be(mobi_offset + 12)?,
            text_record_count: reader.u16be(8)?,
            record_size: reader.u16be(10)?,
            full_name_offset,
            full_name_length,
            exth_flags,
            first_image_record_index,
        })
    }
}
