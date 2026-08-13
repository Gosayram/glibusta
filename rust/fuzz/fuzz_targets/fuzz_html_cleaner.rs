use libfuzzer_sys::fuzz_target;

// Fuzz the TXT parser — tests regex chapter splitting, encoding detection
fuzz_target!(|data: &[u8]| {
    let _ = glibusta_core::book::txt::parse_txt(data, None);
});
