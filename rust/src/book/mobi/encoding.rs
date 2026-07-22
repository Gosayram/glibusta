pub(crate) fn decode_utf16(bytes: &[u8]) -> String {
    if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        return decode_utf16_units(&bytes[2..], u16::from_le_bytes);
    }
    if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        return decode_utf16_units(&bytes[2..], u16::from_be_bytes);
    }

    // MOBI's UTF-16 code page does not require a BOM. Treat BOM-less input as
    // little-endian, but still decode the complete u16 sequence so surrogate
    // pairs survive rather than being silently discarded one unit at a time.
    decode_utf16_units(bytes, u16::from_le_bytes)
}

fn decode_utf16_units(bytes: &[u8], from_bytes: fn([u8; 2]) -> u16) -> String {
    let units: Vec<u16> = bytes
        .chunks_exact(2)
        .map(|chunk| from_bytes([chunk[0], chunk[1]]))
        .collect();
    String::from_utf16_lossy(&units)
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
    if let Ok(utf8_text) = std::str::from_utf8(bytes) {
        return utf8_text.to_owned();
    }
    let (decoded, _, _) = encoding_rs::WINDOWS_1252.decode(bytes);
    decoded.into_owned()
}
