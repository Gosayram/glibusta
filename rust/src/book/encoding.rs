use encoding_rs::Encoding;
use quick_xml::events::BytesStart;

pub(crate) fn get_xml_attr(e: &BytesStart<'_>, name: &[u8]) -> Option<String> {
    e.attributes()
        .filter_map(|a| a.ok())
        .find(|a| a.key.as_ref() == name)
        .map(|a| String::from_utf8_lossy(&a.value).into_owned())
}

pub(crate) fn decode_bytes(bytes: &[u8], encoding_name: &str) -> String {
    if encoding_name.eq_ignore_ascii_case("utf-8") {
        String::from_utf8_lossy(bytes).into_owned()
    } else {
        let (decoded, _, _) = Encoding::for_label(encoding_name.as_bytes())
            .unwrap_or(encoding_rs::UTF_8)
            .decode(bytes);
        decoded.into_owned()
    }
}
