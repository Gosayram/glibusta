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

    pub fn parse(&self, record0: &[u8]) -> Result<MobiHeader> {
        let reader = BinaryReader::new(record0);
        let mobi_offset = Self::MOBI_OFFSET;

        if reader.ascii(mobi_offset, 4)? != "MOBI" {
            bail!("Invalid MOBI header");
        }

        Ok(MobiHeader {
            compression: reader.u16be(0)?,
            encryption_type: reader.u16be(12)?,
            text_length: reader.u32be(4)?,
            text_encoding: reader.u16be(mobi_offset + 12)?,
            text_record_count: reader.u16be(8)?,
            record_size: reader.u16be(10)?,
            full_name_offset: reader.u32be(mobi_offset + 84)?,
            full_name_length: reader.u32be(mobi_offset + 88)?,
            exth_flags: reader.u32be(mobi_offset + 128)?,
            first_image_record_index: reader.u32be(mobi_offset + 108)?,
        })
    }
}
