//! Opt-in compatibility check against the locally installed DjVuLibre tools.
//!
//! DjVuLibre is GPL-2.0-or-later and deliberately is not linked into the app.
//! This test instead compares its `djvutxt` output with the pure-Rust runtime
//! decoder on a deterministic fixture. Run it with `make djvu-oracle-check`.

use glibusta_core::book::djvu::DjvuEngine;
use std::fs;
use std::process::Command;

/// 4×4 DjVu with the `Hello World` hidden text layer.
const DJVU_WITH_TEXT: &[u8] = &[
    0x41, 0x54, 0x26, 0x54, 0x46, 0x4f, 0x52, 0x4d, 0x00, 0x00, 0x00, 0x4c, 0x44, 0x4a, 0x56, 0x55,
    0x49, 0x4e, 0x46, 0x4f, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x04, 0x00, 0x04, 0x18, 0x00, 0x2c, 0x01,
    0x16, 0x01, 0x53, 0x6a, 0x62, 0x7a, 0x00, 0x00, 0x00, 0x07, 0x9b, 0x69, 0xe7, 0xba, 0xed, 0x93,
    0x17, 0x00, 0x54, 0x58, 0x54, 0x7a, 0x00, 0x00, 0x00, 0x1e, 0xff, 0xff, 0xde, 0x88, 0xce, 0x6e,
    0xd5, 0x2c, 0x80, 0x35, 0xfb, 0x4e, 0x14, 0xf9, 0xd7, 0x47, 0x14, 0x6e, 0x25, 0xf0, 0xfb, 0x3a,
    0x67, 0xfa, 0x55, 0xde, 0xb2, 0x8e, 0xed, 0xbf,
];

#[test]
#[ignore = "requires an explicitly requested, locally installed DjVuLibre djvutxt tool"]
fn djvu_rs_text_matches_djvulibre_reference() {
    let path =
        std::env::temp_dir().join(format!("glibusta-djvu-oracle-{}.djvu", std::process::id()));
    fs::write(&path, DJVU_WITH_TEXT).expect("write deterministic DjVu fixture");

    let result = Command::new("djvutxt")
        .arg(&path)
        .output()
        .expect("run locally installed DjVuLibre djvutxt");
    let _ = fs::remove_file(&path);

    assert!(
        result.status.success(),
        "DjVuLibre djvutxt failed: {}",
        String::from_utf8_lossy(&result.stderr)
    );

    let reference = String::from_utf8(result.stdout).expect("DjVuLibre text must be UTF-8");
    let runtime = DjvuEngine::extract_text(DJVU_WITH_TEXT).expect("djvu-rs extracts fixture text");
    assert_eq!(runtime.trim(), reference.trim());
}
