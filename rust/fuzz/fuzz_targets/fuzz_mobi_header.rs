use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let _ = glibusta_core::book::mobi::parse_mobi(data, None);
});
