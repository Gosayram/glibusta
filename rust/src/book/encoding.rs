use encoding_rs::Encoding;
use quick_xml::events::BytesStart;

pub(crate) fn get_xml_attr(e: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    let attr = e.try_get_attribute(name).ok()??;
    Some(String::from_utf8_lossy(&attr.value).into_owned())
}

/// Check if an attribute equals a byte-string value (no allocation).
pub(crate) fn attr_eq(e: &BytesStart<'_>, name: &[u8], expected: &[u8]) -> bool {
    e.try_get_attribute(name)
        .ok()
        .flatten()
        .is_some_and(|attr| attr.value.as_ref() == expected)
}

pub(crate) fn decode_bytes(bytes: &[u8], encoding_name: &str) -> String {
    let encoding = if encoding_name.eq_ignore_ascii_case("utf-8") {
        encoding_rs::UTF_8
    } else {
        Encoding::for_label(encoding_name.as_bytes()).unwrap_or(encoding_rs::UTF_8)
    };
    let (decoded, _) = encoding.decode_without_bom_handling(bytes);
    decoded.into_owned()
}

/// Detect text encoding using chardetng, with BOM/UTF-8 fast-paths.
pub(crate) fn detect_encoding(bytes: &[u8]) -> &'static str {
    // BOM detection
    if bytes.len() >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
        return "utf-8";
    }
    if bytes.len() >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE {
        return "utf-16le";
    }
    if bytes.len() >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF {
        return "utf-16be";
    }

    // Fast path: valid UTF-8
    if std::str::from_utf8(bytes).is_ok() {
        return "utf-8";
    }

    // Statistical detection via chardetng
    let mut detector = chardetng::EncodingDetector::new(chardetng::Iso2022JpDetection::Allow);
    detector.feed(bytes, true);
    let encoding = detector.guess(None, chardetng::Utf8Detection::Allow);
    encoding.name()
}
