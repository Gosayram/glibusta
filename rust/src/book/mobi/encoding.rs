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

pub(crate) fn decode_text(
    bytes: &[u8],
    text_encoding: u16,
    forced_encoding: Option<&str>,
) -> String {
    if let Some(decoded) = forced_encoding.and_then(|encoding| decode_forced(bytes, encoding)) {
        return decoded;
    }
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

/// Decode a user-selected encoding when it is one supported by the reader.
///
/// MOBI stores an encoding in its header, but a corrupt or incorrectly
/// converted file can declare the wrong value.  The import path exposes the
/// same per-book override for every text format, so honour it here as well.
/// Unknown labels deliberately fall back to the header's controlled decoder.
fn decode_forced(bytes: &[u8], encoding: &str) -> Option<String> {
    let label = encoding.trim();
    if label.eq_ignore_ascii_case("utf-8") || label.eq_ignore_ascii_case("utf8") {
        return Some(String::from_utf8_lossy(bytes).into_owned());
    }
    if label.eq_ignore_ascii_case("utf-16") || label.eq_ignore_ascii_case("utf-16le") {
        return Some(decode_utf16_units(bytes, u16::from_le_bytes));
    }
    if label.eq_ignore_ascii_case("utf-16be") {
        return Some(decode_utf16_units(bytes, u16::from_be_bytes));
    }

    encoding_rs::Encoding::for_label(label.as_bytes()).map(|encoding| {
        let (decoded, _, _) = encoding.decode(bytes);
        decoded.into_owned()
    })
}
