pub(crate) fn decode_utf16(bytes: &[u8]) -> String {
    if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        let units: Vec<u16> = bytes[2..]
            .chunks_exact(2)
            .map(|c| u16::from_le_bytes([c[0], c[1]]))
            .collect();
        return String::from_utf16_lossy(&units);
    }
    if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        let units: Vec<u16> = bytes[2..]
            .chunks_exact(2)
            .map(|c| u16::from_be_bytes([c[0], c[1]]))
            .collect();
        return String::from_utf16_lossy(&units);
    }
    let mut buf = String::with_capacity(bytes.len() / 2);
    let mut i = 0;
    while i + 1 < bytes.len() {
        let code = (bytes[i] as u32) | ((bytes[i + 1] as u32) << 8);
        if let Some(c) = char::from_u32(code) {
            buf.push(c);
        }
        i += 2;
    }
    buf
}

pub(crate) fn decode_text(bytes: &[u8], text_encoding: u16) -> String {
    if text_encoding == 65001 {
        return String::from_utf8_lossy(bytes).into_owned();
    }
    if text_encoding == 65002 {
        return decode_utf16(bytes);
    }
    if text_encoding == 1252 {
        let (decoded, _, _) = encoding_rs::WINDOWS_1252.decode(bytes);
        return decoded.into_owned();
    }
    let utf8_text = String::from_utf8_lossy(bytes).into_owned();
    let replacement_count = utf8_text.matches('\u{FFFD}').count();
    if (replacement_count as f64) < (bytes.len() as f64 * 0.02) {
        return utf8_text;
    }
    let (decoded, _, _) = encoding_rs::WINDOWS_1252.decode(bytes);
    decoded.into_owned()
}
