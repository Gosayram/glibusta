use libfuzzer_sys::fuzz_target;

fuzz_target!(|data: &[u8]| {
    let _ = glibusta_core::book::fb2::parse_fb2(data, None);
});
