use anyhow::{Result, bail};

use super::MAX_DECOMPRESSED_RECORD_BYTES;

pub(crate) struct PalmDocDecompressor;

impl PalmDocDecompressor {
    pub fn decompress(&self, input: &[u8]) -> Result<Vec<u8>> {
        let mut out = Vec::with_capacity(input.len().min(MAX_DECOMPRESSED_RECORD_BYTES));
        let mut i = 0;

        while i < input.len() {
            let c = input[i];
            i += 1;

            if c == 0 {
                ensure_output_space(out.len(), 1)?;
                out.push(c);
            } else if c <= 8 {
                let literal_len = usize::from(c);
                if input.len().saturating_sub(i) < literal_len {
                    bail!("Truncated PalmDOC literal run");
                }
                ensure_output_space(out.len(), literal_len)?;
                out.extend_from_slice(&input[i..i + literal_len]);
                i += literal_len;
            } else if c <= 0x7F {
                ensure_output_space(out.len(), 1)?;
                out.push(c);
            } else if c <= 0xBF {
                if i >= input.len() {
                    bail!("Truncated PalmDOC back reference");
                }
                let c2 = input[i];
                i += 1;
                let distance = (((c & 0x3F) as usize) << 5) | ((c2 >> 3) as usize);
                let length = ((c2 & 0x07) as usize) + 3;
                if distance == 0 || distance > out.len() {
                    bail!("Invalid PalmDOC back reference");
                }
                ensure_output_space(out.len(), length)?;
                let start = out.len() - distance;
                for j in 0..length {
                    let ch = out[start + j];
                    out.push(ch);
                }
            } else {
                ensure_output_space(out.len(), 2)?;
                out.push(0x20);
                out.push(c ^ 0x80);
            }
        }

        Ok(out)
    }
}

fn ensure_output_space(current_len: usize, additional: usize) -> Result<()> {
    if additional > MAX_DECOMPRESSED_RECORD_BYTES.saturating_sub(current_len) {
        bail!("MOBI record is too large after decompression");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{MAX_DECOMPRESSED_RECORD_BYTES, PalmDocDecompressor};

    #[test]
    fn rejects_zero_distance_back_reference() {
        let error = PalmDocDecompressor
            .decompress(&[0x80, 0x00])
            .expect_err("zero-distance back reference must be rejected");

        assert!(error.to_string().contains("back reference"));
    }

    #[test]
    #[cfg_attr(
        miri,
        ignore = "8 MiB decompression-limit test is prohibitively slow under Miri"
    )]
    fn rejects_output_that_exceeds_record_limit() {
        let input = vec![b'a'; MAX_DECOMPRESSED_RECORD_BYTES + 1];
        let error = PalmDocDecompressor
            .decompress(&input)
            .expect_err("record larger than the decompression limit must be rejected");

        assert!(error.to_string().contains("too large"));
    }
}
