use anyhow::{bail, Result};

use super::MAX_DECOMPRESSED_RECORD_BYTES;

pub(crate) struct PalmDocDecompressor;

impl PalmDocDecompressor {
    pub fn decompress(&self, input: &[u8]) -> Result<Vec<u8>> {
        let mut out: Vec<u8> = Vec::with_capacity(input.len() * 3);
        let mut i = 0;

        while i < input.len() {
            if out.len() > MAX_DECOMPRESSED_RECORD_BYTES {
                bail!("MOBI record is too large after decompression");
            }
            let c = input[i];
            i += 1;

            if c == 0 {
                out.push(c);
            } else if c <= 8 {
                for _ in 0..c {
                    if i >= input.len() {
                        break;
                    }
                    out.push(input[i]);
                    i += 1;
                }
            } else if c <= 0x7F {
                out.push(c);
            } else if c <= 0xBF {
                if i >= input.len() {
                    break;
                }
                let c2 = input[i];
                i += 1;
                let distance = (((c & 0x3F) as usize) << 5) | ((c2 >> 3) as usize);
                let length = ((c2 & 0x07) as usize) + 3;
                let start = out.len().checked_sub(distance);
                let start = match start {
                    Some(s) => s,
                    None => bail!("Invalid PalmDOC back reference"),
                };
                for j in 0..length {
                    let ch = out[start + j];
                    out.push(ch);
                }
            } else {
                out.push(0x20);
                out.push(c ^ 0x80);
            }
        }

        Ok(out)
    }
}
