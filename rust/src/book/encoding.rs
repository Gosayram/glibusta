use encoding_rs::Encoding;
use quick_xml::events::BytesStart;

pub(crate) fn get_xml_attr(e: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    let attr = e.try_get_attribute(name).ok()??;
    Some(String::from_utf8_lossy(&attr.value).into_owned())
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
