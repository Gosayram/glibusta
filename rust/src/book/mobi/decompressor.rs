use anyhow::{Result, bail};

pub(crate) struct PalmDocDecompressor;

impl PalmDocDecompressor {
    pub fn decompress_limited(&self, input: &[u8], max_output_bytes: usize) -> Result<Vec<u8>> {
        let mut out = Vec::with_capacity(input.len().min(max_output_bytes));
        let mut i = 0;

        while i < input.len() {
            let c = input[i];
            i += 1;

            if c == 0 {
                ensure_output_space(out.len(), 1, max_output_bytes)?;
                out.push(c);
            } else if c <= 8 {
                let literal_len = usize::from(c);
                if input.len().saturating_sub(i) < literal_len {
                    bail!("Truncated PalmDOC literal run");
                }
                ensure_output_space(out.len(), literal_len, max_output_bytes)?;
                out.extend_from_slice(&input[i..i + literal_len]);
                i += literal_len;
            } else if c <= 0x7F {
                ensure_output_space(out.len(), 1, max_output_bytes)?;
                out.push(c);
            } else if c <= 0xBF {
                if i >= input.len() {
                    bail!("Truncated PalmDOC back reference");
                }
                let c2 = input[i];
                i += 1;
                let distance = (((c & 0x3F) as usize) << 8) | (c2 as usize);
                let length = ((c2 >> 3) as usize) + 3;
                if distance == 0 || distance > out.len() {
                    bail!("Invalid PalmDOC back reference");
                }
                ensure_output_space(out.len(), length, max_output_bytes)?;
                let start = out.len() - distance;
                for j in 0..length {
                    let ch = out[start + j];
                    out.push(ch);
                }
            } else {
                ensure_output_space(out.len(), 2, max_output_bytes)?;
                out.push(0x20);
                out.push(c ^ 0x80);
            }
        }

        Ok(out)
    }
}

fn ensure_output_space(
    current_len: usize,
    additional: usize,
    max_output_bytes: usize,
) -> Result<()> {
    if additional > max_output_bytes.saturating_sub(current_len) {
        bail!("MOBI record is too large after decompression");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::PalmDocDecompressor;

    #[test]
    fn rejects_zero_distance_back_reference() {
        let error = PalmDocDecompressor
            .decompress_limited(&[0x80, 0x00], 4096)
            .expect_err("zero-distance back reference must be rejected");

        assert!(error.to_string().contains("back reference"));
    }

    #[test]
    fn rejects_output_that_exceeds_record_limit() {
        let input = vec![b'a'; 4097];
        let error = PalmDocDecompressor
            .decompress_limited(&input, 4096)
            .expect_err("record larger than the decompression limit must be rejected");

        assert!(error.to_string().contains("too large"));
    }
}
