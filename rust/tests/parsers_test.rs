use std::fs;
use std::io::Write;

use glibusta_core::{BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, TocEntry};

#[test]
fn test_path_cache_invalidates_when_source_file_is_replaced() {
    let path = std::env::temp_dir().join(format!(
        "glibusta_cache_fingerprint_{}_{}.txt",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    let path_text = path.to_string_lossy().into_owned();

    fs::write(&path, "Original title\n\nOriginal text.").expect("write first fixture");
    let first =
        glibusta_core::api::api::parse_book(path_text.clone()).expect("parse first fixture");
    assert_eq!(first.title, "Original title");
    assert!(
        !glibusta_core::api::api::check_book_cache(path_text.clone())
            .expect("check first cache")
            .0
    );

    // A different size makes the assertion independent of filesystem mtime precision.
    fs::write(
        &path,
        "Replacement title\n\nReplacement text with a different length.",
    )
    .expect("replace fixture");
    let replacement =
        glibusta_core::api::api::parse_book(path_text.clone()).expect("parse replacement fixture");
    assert_eq!(replacement.title, "Replacement title");

    fs::remove_file(path).expect("remove cache fixture");
}

#[cfg(not(miri))]
#[test]
fn test_large_fb2_path_import_is_bounded_and_preserves_structure() {
    const PARAGRAPH_COUNT: usize = 256;
    const PARAGRAPH_BYTES: usize = 4096;

    let path = std::env::temp_dir().join(format!(
        "glibusta-large-fb2-{}_{}.fb2",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    let payload = "x".repeat(PARAGRAPH_BYTES);
    let mut xml = String::with_capacity(PARAGRAPH_COUNT * (PARAGRAPH_BYTES + 8));
    xml.push_str("<FictionBook><description><title-info><book-title>Large fixture</book-title></title-info></description><body><section>");
    for _ in 0..PARAGRAPH_COUNT {
        xml.push_str("<p>");
        xml.push_str(&payload);
        xml.push_str("</p>");
    }
    xml.push_str("</section></body></FictionBook>");
    assert!(
        xml.len() >= 1024 * 1024,
        "fixture must exercise a large input"
    );
    fs::write(&path, xml).expect("write large FB2 fixture");

    let started = std::time::Instant::now();
    let result = glibusta_core::api::api::parse_book(path.to_string_lossy().into_owned());
    let elapsed = started.elapsed();
    let _ = fs::remove_file(path);

    let book = result.expect("large FB2 path import");
    assert_eq!(book.title, "Large fixture");
    assert_eq!(book.chapters.len(), 1);
    assert_eq!(book.chapters[0].blocks.len(), PARAGRAPH_COUNT);
    // This is a liveness guard, not a machine-performance target: it catches
    // accidental unbounded work while leaving broad headroom for debug builds.
    assert!(elapsed < std::time::Duration::from_secs(30), "{elapsed:?}");
}

// ---------------------------------------------------------------------------
// FB2 tests — parse from XML string
// ---------------------------------------------------------------------------

const MINIMAL_FB2: &str = r#"<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <genre>science_fiction</genre>
      <author><first-name>Иван</first-name><last-name>Ефремов</last-name></author>
      <book-title>Туманность Андромеды</book-title>
      <lang>ru</lang>
      <annotation><p>Знаменитый роман.</p></annotation>
    </title-info>
  </description>
  <body>
    <section>
      <title><p>Глава 1</p></title>
      <p>Звёзды сияли над пустыней.</p>
      <p>Ветер доносил запах полыни.</p>
    </section>
    <section>
      <title><p>Глава 2</p></title>
      <p>Корабль приближался к цели.</p>
    </section>
  </body>
</FictionBook>"#;

const FB2_WITH_COVER: &str = r#"<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info>
      <author><first-name>Тест</first-name><last-name>Тестов</last-name></author>
      <book-title>Книга с обложкой</book-title>
      <lang>ru</lang>
    </title-info>
  </description>
  <body>
    <section>
      <p>Текст книги.</p>
    </section>
  </body>
  <binary id="cover.jpg" content-type="image/jpeg">/9j/4AAQSkZJRg==</binary>
</FictionBook>"#;

#[test]
fn test_fb2_basic_metadata() {
    let book = glibusta_core::book::fb2::parse_fb2(MINIMAL_FB2.as_bytes(), None).unwrap();
    assert_eq!(book.title, "Туманность Андромеды");
    assert_eq!(book.authors, vec!["Иван Ефремов"]);
    assert_eq!(book.language, Some("ru".to_string()));
    assert!(book.description.unwrap().contains("Знаменитый"));
    assert_eq!(book.book_format, BookFormat::Fb2);
}

#[test]
fn test_fb2_chapters() {
    let book = glibusta_core::book::fb2::parse_fb2(MINIMAL_FB2.as_bytes(), None).unwrap();
    assert!(
        book.chapters.len() >= 2,
        "expected at least 2 chapters, got {}",
        book.chapters.len()
    );
    assert_eq!(book.chapters[0].blocks.len(), 3);
    assert_eq!(book.chapters[1].blocks.len(), 2);
}

#[test]
fn test_fb2_with_cover() {
    let book = glibusta_core::book::fb2::parse_fb2(FB2_WITH_COVER.as_bytes(), None).unwrap();
    assert!(book.cover_url.is_some(), "cover_url should be present");
    assert!(
        book.cover_url
            .unwrap()
            .starts_with("data:image/jpeg;base64,")
    );
}

#[test]
fn test_fb2_default_title_on_empty() {
    let xml = br#"<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description><title-info></title-info></description>
  <body><section><p>Only text.</p></section></body>
</FictionBook>"#;
    let book = glibusta_core::book::fb2::parse_fb2(xml, None).unwrap();
    assert!(!book.chapters.is_empty());
}

#[test]
fn test_fb2_zip_finds_case_insensitive_entry_name() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("BOOK.FB2", options)
        .expect("create FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write FB2 fixture");
    zip.finish().expect("finish FB2.ZIP fixture");

    let book = glibusta_core::book::fb2::parse_fb2(&buffer.into_inner(), None)
        .expect("parse FB2.ZIP with uppercase extension");

    assert_eq!(book.title, "Туманность Андромеды");
}

#[test]
fn test_fb2_zip_skips_macos_metadata_before_the_book() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("__MACOSX/book.fb2", options)
        .expect("create macOS metadata entry");
    zip.write_all(b"not an FB2 document")
        .expect("write macOS metadata entry");
    zip.start_file("book.fb2", options)
        .expect("create FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write FB2 fixture");
    zip.finish().expect("finish FB2.ZIP fixture");

    let book = glibusta_core::book::fb2::parse_fb2(&buffer.into_inner(), None)
        .expect("parse FB2.ZIP while skipping macOS metadata");

    assert_eq!(book.title, "Туманность Андромеды");
}

#[test]
fn test_fb2_zip_ignores_path_traversal_book_entry() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("../untrusted.fb2", options)
        .expect("create traversal entry");
    zip.write_all(
        MINIMAL_FB2
            .replace("Туманность Андромеды", "Untrusted book")
            .as_bytes(),
    )
    .expect("write traversal fixture");
    zip.start_file("book.fb2", options)
        .expect("create regular FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write regular FB2 fixture");
    zip.finish().expect("finish FB2.ZIP fixture");

    let book = glibusta_core::book::fb2::parse_fb2(&buffer.into_inner(), None)
        .expect("ignore unsafe archive path and parse regular FB2");

    assert_eq!(book.title, "Туманность Андромеды");
}

#[test]
fn test_fb2_zip_uses_the_first_regular_book_when_multiple_are_present() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("first.fb2", options)
        .expect("create first FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write first FB2 fixture");
    zip.start_file("second.fb2", options)
        .expect("create second FB2 entry");
    zip.write_all(
        MINIMAL_FB2
            .replace("Туманность Андромеды", "Second book")
            .as_bytes(),
    )
    .expect("write second FB2 fixture");
    zip.finish().expect("finish multi-book FB2.ZIP fixture");

    let book = glibusta_core::book::fb2::parse_fb2(&buffer.into_inner(), None)
        .expect("parse the first regular FB2 from a multi-book archive");

    assert_eq!(book.title, "Туманность Андромеды");
}

#[test]
fn test_path_parser_opens_fb2_zip() {
    let path = std::env::temp_dir().join(format!(
        "glibusta_fb2_zip_{}_{}.fb2.zip",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("book.fb2", options)
        .expect("create FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write FB2 fixture");
    zip.finish().expect("finish FB2.ZIP fixture");
    fs::write(&path, buffer.into_inner()).expect("write FB2.ZIP fixture");

    let result = glibusta_core::api::api::parse_book(path.to_string_lossy().into_owned());
    let _ = fs::remove_file(&path);
    let book = result.expect("path parser should open .fb2.zip");

    assert_eq!(book.title, "Туманность Андромеды");
}

#[test]
fn test_sequential_fb2_zip_and_epub_opens_do_not_leak_archive_or_parser_state() {
    let directory = std::env::temp_dir().join(format!(
        "glibusta-sequential-archive-parser-{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    fs::create_dir_all(&directory).expect("create fixture directory");
    let fb2_a_path = directory.join("first.zip");
    let epub_path = directory.join("middle.epub");
    let fb2_b_path = directory.join("last.zip");

    let fb2_zip = |title: &str| {
        let mut buffer = std::io::Cursor::new(Vec::new());
        let mut zip = zip::ZipWriter::new(&mut buffer);
        let options = zip::write::FileOptions::<()>::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("book.fb2", options)
            .expect("create FB2 entry");
        zip.write_all(
            MINIMAL_FB2
                .replace("Туманность Андромеды", title)
                .as_bytes(),
        )
        .expect("write FB2 fixture");
        zip.finish().expect("finish FB2.ZIP fixture");
        buffer.into_inner()
    };
    fs::write(&fb2_a_path, fb2_zip("First ZIP book")).expect("write first FB2.ZIP");
    fs::write(&epub_path, create_minimal_epub()).expect("write EPUB");
    fs::write(&fb2_b_path, fb2_zip("Last ZIP book")).expect("write last FB2.ZIP");

    let result = (|| {
        let first = glibusta_core::api::api::parse_book(fb2_a_path.to_string_lossy().into_owned())?;
        let epub = glibusta_core::api::api::parse_book(epub_path.to_string_lossy().into_owned())?;
        let last = glibusta_core::api::api::parse_book(fb2_b_path.to_string_lossy().into_owned())?;
        anyhow::Result::<_>::Ok((first, epub, last))
    })();
    let _ = fs::remove_dir_all(&directory);

    let (first, epub, last) = result.expect("sequential archive parsing");
    assert_eq!(first.title, "First ZIP book");
    assert_eq!(epub.title, "Test EPUB");
    assert_eq!(last.title, "Last ZIP book");
    assert_eq!(first.book_format, BookFormat::Fb2);
    assert_eq!(epub.book_format, BookFormat::Epub);
    assert_eq!(last.book_format, BookFormat::Fb2);
}

#[test]
fn test_fb2_zip_rejects_a_corrupted_entry() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("book.fb2", options)
        .expect("create FB2 entry");
    zip.write_all(MINIMAL_FB2.as_bytes())
        .expect("write FB2 fixture");
    zip.finish().expect("finish FB2.ZIP fixture");

    let mut bytes = buffer.into_inner();
    let payload_start = bytes
        .windows(b"<FictionBook".len())
        .position(|window| window == b"<FictionBook")
        .expect("locate stored FB2 payload");
    bytes[payload_start] ^= 1;

    let error = glibusta_core::book::fb2::parse_fb2(&bytes, None)
        .expect_err("a ZIP entry with an invalid CRC must be rejected");
    assert!(error.to_string().contains("Failed to extract ZIP entry"));
}

#[test]
fn test_fb2_zip_resolves_relative_image_resources() {
    let mut buffer = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buffer);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("book.fb2", options)
        .expect("create FB2 entry");
    zip.write_all(
        br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description/><body><section><image l:href="images/page.webp"/></section></body></FictionBook>"##,
    )
    .expect("write FB2 fixture");
    zip.start_file("images/page.webp", options)
        .expect("create image entry");
    zip.write_all(&[0x52, 0x49, 0x46, 0x46])
        .expect("write image entry");
    zip.finish().expect("finish FB2.ZIP fixture");

    let book = glibusta_core::book::fb2::parse_fb2(&buffer.into_inner(), None)
        .expect("parse FB2.ZIP with external image resource");

    assert_eq!(
        book.chapters[0].blocks[0].image_url.as_deref(),
        Some("data:image/webp;base64,UklGRg==")
    );
}

#[test]
fn test_fb2_preserves_paragraphs_with_windows_line_endings() {
    let xml = MINIMAL_FB2.replace("\n", "\r\n");

    let book = glibusta_core::book::fb2::parse_fb2(xml.as_bytes(), None)
        .expect("parse FB2 with Windows line endings");
    let blocks = &book.chapters[0].blocks;

    assert!(
        blocks
            .iter()
            .any(|block| block.text == "Звёзды сияли над пустыней.")
    );
    assert!(
        blocks
            .iter()
            .any(|block| block.text == "Ветер доносил запах полыни.")
    );
}

// ---------------------------------------------------------------------------
// TXT tests — encoding detection + chapter splitting
// ---------------------------------------------------------------------------

#[test]
fn test_txt_utf8_plain() {
    let text =
        "\u{41}\u{43}\u{43}\u{6f}\u{75}\u{6e}\u{74}\n\n\u{41} \u{62}\u{6f}\u{6f}\u{6b}\u{2e}\n"
            .to_string();
    let book = glibusta_core::book::txt::parse_txt(text.as_bytes(), None).unwrap();
    assert!(!book.title.is_empty());
    assert_eq!(book.book_format, BookFormat::Txt);
}

#[test]
fn test_txt_chapter_detection_russian() {
    let text = concat!(
        "\u{41} \u{42}\u{6f}\u{6f}\u{6b}\n\n",
        "\u{47}\u{43}\u{61}\u{432}\u{430} 1\n\n",
        "\u{41} \u{62}\u{6c}\u{6f}\u{63}\u{6b}.\n\n",
        "\u{47}\u{43}\u{61}\u{432}\u{430} 2\n\n",
        "\u{41}\u{6e}\u{6f}\u{74}\u{68}\u{65}\u{72} \u{62}\u{6c}\u{6f}\u{63}\u{6b}.\n\n",
    );
    let book = glibusta_core::book::txt::parse_txt(text.as_bytes(), None).unwrap();
    assert!(!book.chapters.is_empty(), "should have chapters");
}

#[test]
fn test_txt_chapter_detection_english() {
    let text = concat!(
        "The Great Novel\n\n",
        "Chapter 1\n\n",
        "It was a dark and stormy night.\n\n",
        "Chapter 2\n\n",
        "The morning dawned clear and bright.\n\n",
    );
    let book = glibusta_core::book::txt::parse_txt(text.as_bytes(), None).unwrap();
    assert_eq!(book.title, "The Great Novel");
}

#[test]
fn test_txt_part_detection() {
    let text = concat!(
        "A Novel\n\n",
        "Part 1\n\n",
        "First part text.\n\n",
        "Part 2\n\n",
        "Second part text.\n\n",
    );
    let book = glibusta_core::book::txt::parse_txt(text.as_bytes(), None).unwrap();
    assert_eq!(book.title, "A Novel");
}

#[test]
fn test_txt_single_chapter_no_split() {
    let text = "Just a book without chapters.\n\nAll text in one para.\n\nAnd some more.\n";
    let book = glibusta_core::book::txt::parse_txt(text.as_bytes(), None).unwrap();
    assert_eq!(book.chapters.len(), 1, "should be a single chapter");
}

// ---------------------------------------------------------------------------
// EPUB tests — minimal in-memory EPUB
// ---------------------------------------------------------------------------

const MINIMAL_EPUB_OPF: &[u8] = br#"<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata>
    <dc:title>Test EPUB</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
    <dc:description>A test EPUB book.</dc:description>
  </metadata>
  <manifest>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="chapter1"/>
  </spine>
</package>"#;

fn create_minimal_epub() -> Vec<u8> {
    create_epub_with_opf(true, MINIMAL_EPUB_OPF)
}

fn create_encrypted_epub() -> Vec<u8> {
    create_epub_with_encryption(
        br#"<?xml version="1.0"?><encryption xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><EncryptedData><EncryptionMethod Algorithm="http://www.w3.org/2001/04/xmlenc#aes256-cbc"/><CipherData><CipherReference URI="chapter1.xhtml"/></CipherData></EncryptedData></encryption>"#,
    )
}

fn create_font_obfuscated_epub(algorithm: &str) -> Vec<u8> {
    create_epub_with_encryption(
        format!(
            "<?xml version=\"1.0\"?><encryption xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><EncryptedData><EncryptionMethod Algorithm=\"{algorithm}\"/><CipherData><CipherReference URI=\"font.woff\"/></CipherData></EncryptedData></encryption>"
        )
        .as_bytes(),
    )
}

fn create_epub_with_encryption(encryption_xml: &[u8]) -> Vec<u8> {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("mimetype", options).unwrap();
    zip.write_all(b"application/epub+zip").unwrap();
    zip.start_file("META-INF/encryption.xml", options).unwrap();
    zip.write_all(encryption_xml).unwrap();
    zip.start_file("META-INF/container.xml", options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>"#,
    )
    .unwrap();
    zip.start_file("content.opf", options).unwrap();
    zip.write_all(MINIMAL_EPUB_OPF).unwrap();
    zip.start_file("chapter1.xhtml", options).unwrap();
    zip.write_all(b"<html><body><p>Encrypted payload</p></body></html>")
        .unwrap();
    zip.finish().unwrap();
    buf.into_inner()
}

fn create_epub_with_opf(include_mimetype: bool, opf: &[u8]) -> Vec<u8> {
    create_epub_with_opf_and_chapter(
        include_mimetype,
        opf,
        br#"<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 1</title></head>
  <body>
    <p>First paragraph.</p>
    <p>Second paragraph.</p>
  </body>
</html>"#,
    )
}

fn create_epub_with_opf_and_chapter(include_mimetype: bool, opf: &[u8], chapter: &[u8]) -> Vec<u8> {
    create_epub_with_named_container_entries(
        include_mimetype.then_some("mimetype"),
        "META-INF/container.xml",
        opf,
        chapter,
    )
}

fn utf16be_xml(xml: &str) -> Vec<u8> {
    let mut bytes = vec![0xFE, 0xFF];
    bytes.extend(xml.encode_utf16().flat_map(u16::to_be_bytes));
    bytes
}

fn create_epub_with_named_container_entries(
    mimetype_entry: Option<&str>,
    container_entry: &str,
    opf: &[u8],
    chapter: &[u8],
) -> Vec<u8> {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);

    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);

    if let Some(mimetype_entry) = mimetype_entry {
        // EPUB requires this as the first, uncompressed ZIP entry.
        zip.start_file(mimetype_entry, options).unwrap();
        zip.write_all(b"application/epub+zip").unwrap();
    }

    zip.start_file(container_entry, options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>"#,
    )
    .unwrap();

    zip.start_file("content.opf", options).unwrap();
    zip.write_all(opf).unwrap();

    zip.start_file("toc.ncx", options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:uid" content="test-id"/>
  </head>
  <docTitle><text>Test EPUB</text></docTitle>
  <navMap>
    <navPoint id="nav1" playOrder="1">
      <navLabel><text>Chapter 1</text></navLabel>
      <content src="chapter1.xhtml"/>
    </navPoint>
  </navMap>
</ncx>"#,
    )
    .unwrap();

    zip.start_file("chapter1.xhtml", options).unwrap();
    zip.write_all(chapter).unwrap();

    zip.finish().unwrap();
    buf.into_inner()
}

#[test]
fn test_epub_basic_parse() {
    let epub_bytes = create_minimal_epub();

    let book = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    assert_eq!(book.title, "Test EPUB");
    assert_eq!(book.authors, vec!["Test Author"]);
    assert_eq!(book.language, Some("en".to_string()));
    assert!(book.description.unwrap().contains("test"));
    assert!(!book.chapters.is_empty(), "should have chapters");
    assert_eq!(book.chapters[0].blocks.len(), 2);
    assert_eq!(book.book_format, BookFormat::Epub);
}

#[test]
fn test_epub_auto_decodes_utf16be_opf_and_xhtml() {
    let opf = utf16be_xml(
        r#"<?xml version="1.0" encoding="UTF-16"?>
<package><metadata><title>UTF-16 package</title><creator>Test Author</creator></metadata>
<manifest><item id="chapter" href="chapter1.xhtml" media-type="application/xhtml+xml"/></manifest>
<spine><itemref idref="chapter"/></spine></package>"#,
    );
    let chapter = utf16be_xml(
        r#"<?xml version="1.0" encoding="UTF-16"?>
<html xmlns="http://www.w3.org/1999/xhtml"><body><p>UTF-16 chapter text.</p></body></html>"#,
    );

    let book = glibusta_core::book::epub::parse_epub(
        &create_epub_with_opf_and_chapter(true, &opf, &chapter),
        None,
    )
    .expect("UTF-16BE EPUB XML resources must parse without a forced encoding");

    assert_eq!(book.title, "UTF-16 package");
    assert_eq!(book.chapters[0].blocks[0].text, "UTF-16 chapter text.");
}

#[test]
fn test_epub_ignores_utf8_bom_in_content_document() {
    let mut chapter = b"\xEF\xBB\xBF".to_vec();
    chapter.extend_from_slice(b"<?xml version=\"1.0\" encoding=\"UTF-8\"?><html><body><p>BOM-safe text.</p></body></html>");

    let book = glibusta_core::book::epub::parse_epub(
        &create_epub_with_opf_and_chapter(true, MINIMAL_EPUB_OPF, &chapter),
        None,
    )
    .expect("UTF-8 BOM content document must parse");

    assert_eq!(book.chapters[0].blocks[0].text, "BOM-safe text.");
}

#[test]
fn test_epub_preserves_numeric_entities_and_unicode_scalars() {
    let chapter = b"<html><body><p>&#x0100; and \xC4\x80.</p></body></html>";
    let book = glibusta_core::book::epub::parse_epub(
        &create_epub_with_opf_and_chapter(true, MINIMAL_EPUB_OPF, chapter),
        None,
    )
    .expect("numeric entities and UTF-8 scalars must parse together");

    assert_eq!(book.chapters[0].blocks[0].text, "\u{0100} and \u{0100}.");
}

#[test]
fn test_epub_honors_iso_8859_1_xml_declaration() {
    let chapter_xml = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><html><body><p>Caf\u{e9}.</p></body></html>";
    let (chapter, _, _) = encoding_rs::WINDOWS_1252.encode(chapter_xml);

    let book = glibusta_core::book::epub::parse_epub(
        &create_epub_with_opf_and_chapter(true, MINIMAL_EPUB_OPF, &chapter),
        None,
    )
    .expect("ISO-8859-1 EPUB XML declaration must be honored");

    assert_eq!(book.chapters[0].blocks[0].text, "Caf\u{e9}.");
}

#[test]
fn test_epub_decodes_mixed_xml_resource_encodings() {
    let mut bytes = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut bytes);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("mimetype", options).unwrap();
    zip.write_all(b"application/epub+zip").unwrap();
    zip.start_file("META-INF/container.xml", options).unwrap();
    zip.write_all(
        br#"<container><rootfiles><rootfile full-path="content.opf"/></rootfiles></container>"#,
    )
    .unwrap();
    zip.start_file("content.opf", options).unwrap();
    zip.write_all(MINIMAL_EPUB_OPF).unwrap();
    zip.start_file("chapter1.xhtml", options).unwrap();
    zip.write_all(b"<html><body><p>Body text.</p></body></html>")
        .unwrap();
    let ncx = "<?xml version=\"1.0\" encoding=\"windows-1251\"?><ncx><navMap><navPoint><navLabel><text>\u{0413}\u{043b}\u{0430}\u{0432}\u{0430}</text></navLabel><content src=\"chapter1.xhtml\"/></navPoint></navMap></ncx>";
    let (ncx, _, _) = encoding_rs::WINDOWS_1251.encode(ncx);
    zip.start_file("toc.ncx", options).unwrap();
    zip.write_all(&ncx).unwrap();
    zip.finish().unwrap();

    let book = glibusta_core::book::epub::parse_epub(&bytes.into_inner(), None)
        .expect("each EPUB XML resource must use its own declared encoding");

    assert_eq!(
        book.toc[0].title,
        "\u{0413}\u{043b}\u{0430}\u{0432}\u{0430}"
    );
}

#[test]
fn test_epub_toc_ncx() {
    let epub_bytes = create_minimal_epub();
    let book = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    assert!(!book.toc.is_empty(), "TOC should have entries");
    assert_eq!(book.toc[0].title, "Chapter 1");
    assert_eq!(book.toc[0].chapter_index, 0, "TOC target must be navigable");
}

#[test]
fn test_epub_svg_cover_wrapper_is_not_a_second_reader_chapter() {
    let mut bytes = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut bytes);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);

    zip.start_file("mimetype", options).unwrap();
    zip.write_all(b"application/epub+zip").unwrap();
    zip.start_file("META-INF/container.xml", options).unwrap();
    zip.write_all(
        br#"<container><rootfiles><rootfile full-path="OEBPS/content.opf"/></rootfiles></container>"#,
    )
    .unwrap();
    zip.start_file("OEBPS/content.opf", options).unwrap();
    zip.write_all(
        br#"<package><metadata><title>SVG cover</title><meta name="cover" content="cover-image"/></metadata><manifest>
          <item id="cover-image" href="images/cover.svg" media-type="image/svg+xml"/>
          <item id="cover-page" href="cover.xhtml" media-type="application/xhtml+xml"/>
          <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        </manifest><spine><itemref idref="cover-page"/><itemref idref="chapter"/></spine></package>"#,
    )
    .unwrap();
    zip.start_file("OEBPS/images/cover.svg", options).unwrap();
    zip.write_all(br#"<svg xmlns="http://www.w3.org/2000/svg"><rect width="1" height="1"/></svg>"#)
        .unwrap();
    zip.start_file("OEBPS/cover.xhtml", options).unwrap();
    zip.write_all(
        br#"<html xmlns="http://www.w3.org/1999/xhtml"><body><svg xmlns="http://www.w3.org/2000/svg"><image href="images/cover.svg"/></svg></body></html>"#,
    )
    .unwrap();
    zip.start_file("OEBPS/chapter.xhtml", options).unwrap();
    zip.write_all(br#"<html><body><p>Actual chapter text.</p></body></html>"#)
        .unwrap();
    zip.finish().unwrap();

    let book = glibusta_core::book::epub::parse_epub(&bytes.into_inner(), None).unwrap();

    assert!(book.cover_url.is_some(), "the SVG remains the book cover");
    assert_eq!(
        book.chapters.len(),
        1,
        "the wrapper must not duplicate the cover page"
    );
    assert_eq!(book.chapters[0].blocks[0].text, "Actual chapter text.");
}

#[test]
fn test_epub_hidden_css_content_is_not_emitted() {
    let epub = create_epub_with_opf_and_chapter(
        true,
        MINIMAL_EPUB_OPF,
        br#"<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <style>
      .hidden { display: none; }
      .invisible { visibility: hidden; }
    </style>
  </head>
  <body>
    <p>Visible <span class="hidden">hidden inline</span> text.</p>
    <p class="hidden">hidden block</p>
    <p class="invisible">invisible block</p>
    <p style="display: none">hidden inline style</p>
    <div class="hidden"><p>hidden descendant</p></div>
  </body>
</html>"#,
    );

    let book = glibusta_core::book::epub::parse_epub(&epub, None).unwrap();
    let text = book.chapters[0]
        .blocks
        .iter()
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert_eq!(text, "Visible text.");
    for hidden in [
        "hidden inline",
        "hidden block",
        "invisible block",
        "hidden inline style",
        "hidden descendant",
    ] {
        assert!(!text.contains(hidden), "hidden content leaked: {hidden}");
    }
}

#[test]
fn test_epub_tables_and_absolute_elements_reflow_as_reader_blocks() {
    let epub = create_epub_with_opf_and_chapter(
        true,
        MINIMAL_EPUB_OPF,
        br#"<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><style>.margin-note { position: absolute; left: 40px; top: 10px; }</style></head>
  <body>
    <p>Opening prose.</p>
    <p class="margin-note">Margin note remains readable.</p>
    <table><tbody>
      <tr><th>Term</th><th>Definition</th></tr>
      <tr><td>EPUB</td><td>Reflowable publication</td></tr>
    </tbody></table>
    <p>Closing prose.</p>
  </body>
</html>"#,
    );

    let book = glibusta_core::book::epub::parse_epub(&epub, None).unwrap();
    let blocks = &book.chapters[0].blocks;
    let text = blocks
        .iter()
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert!(text.contains("Margin note remains readable."));
    assert!(text.contains("Term | Definition\nEPUB | Reflowable publication"));
    assert!(
        blocks.iter().any(|block| {
            block.block_type == BlockType::Table
                && block.table_rows.as_deref()
                    == Some(&[
                        vec!["Term".to_string(), "Definition".to_string()],
                        vec!["EPUB".to_string(), "Reflowable publication".to_string()],
                    ])
        }),
        "tables must remain structured reader blocks"
    );
}

#[test]
fn test_epub_discards_active_markup_and_footnote_background_assets() {
    let epub = create_epub_with_opf_and_chapter(
        true,
        MINIMAL_EPUB_OPF,
        br#"<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
  <head><style>.footnote { background-image: url('tracking.png'); }</style></head>
  <body>
    <p>Visible <script>alert('not reader text')</script><iframe srcdoc="&lt;p&gt;active&lt;/p&gt;">fallback frame text</iframe> prose.</p>
    <aside epub:type="footnote" class="footnote"><p>Legitimate footnote.</p></aside>
  </body>
</html>"#,
    );

    let book = glibusta_core::book::epub::parse_epub(&epub, None).unwrap();
    let blocks = &book.chapters[0].blocks;
    let text = blocks
        .iter()
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert!(text.contains("Visible"));
    assert!(text.contains("prose."));
    assert!(text.contains("Legitimate footnote."));
    for rejected in ["alert('not reader text')", "fallback frame text", "active"] {
        assert!(!text.contains(rejected), "active markup leaked: {rejected}");
    }
    assert!(blocks.iter().all(|block| block.image_url.is_none()));
}

#[test]
fn test_epub_corrupted_archive_is_rejected() {
    let error = glibusta_core::book::epub::parse_epub(b"not an EPUB archive", None)
        .expect_err("corrupted EPUB must not be parsed");

    assert!(error.to_string().contains("Failed to open EPUB archive"));
}

#[test]
fn test_encrypted_epub_returns_controlled_error_without_caching_a_partial_book() {
    let path = std::env::temp_dir().join(format!(
        "glibusta-encrypted-epub-{}_{}.epub",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    let path_text = path.to_string_lossy().into_owned();
    fs::write(&path, create_encrypted_epub()).expect("write encrypted EPUB fixture");

    let result = glibusta_core::api::api::parse_book(path_text.clone());
    let cache_state = glibusta_core::api::api::check_book_cache(path_text);
    let _ = fs::remove_file(path);

    let error = result.expect_err("encrypted EPUB must not be partially imported");
    assert!(
        error
            .to_string()
            .contains("EPUB encryption algorithm is not supported")
    );
    assert!(
        cache_state.expect("check encrypted EPUB cache state").0,
        "a rejected EPUB must not be cached",
    );
}

#[test]
fn test_epub_allows_idpf_and_adobe_font_obfuscation() {
    for algorithm in [
        "http://www.idpf.org/2008/embedding",
        "http://ns.adobe.com/pdf/enc#RC",
    ] {
        let book =
            glibusta_core::book::epub::parse_epub(&create_font_obfuscated_epub(algorithm), None)
                .unwrap_or_else(|error| {
                    panic!("font obfuscation must be accepted for {algorithm}: {error}")
                });

        assert_eq!(book.title, "Test EPUB");
        assert!(
            book.chapters[0].blocks[0]
                .text
                .contains("Encrypted payload")
        );
    }
}

#[test]
fn test_epub_without_mimetype_is_rejected() {
    let error =
        glibusta_core::book::epub::parse_epub(&create_epub_with_opf(false, MINIMAL_EPUB_OPF), None)
            .expect_err("EPUB without a mimetype entry must not be accepted");

    assert!(error.to_string().contains("mimetype"));
}

#[test]
fn test_epub_with_uppercase_mimetype_entry_is_rejected() {
    // EPUB 3.3 OCF paths are case-sensitive, and the required root entry is
    // specifically named `mimetype`; accepting `MIMETYPE` would accept a
    // non-conformant EPUB container.
    let epub = create_epub_with_named_container_entries(
        Some("MIMETYPE"),
        "META-INF/container.xml",
        MINIMAL_EPUB_OPF,
        b"<html><body><p>Chapter</p></body></html>",
    );

    let error = glibusta_core::book::epub::parse_epub(&epub, None)
        .expect_err("uppercase mimetype entry must not be accepted as EPUB");

    assert!(error.to_string().contains("mimetype"));
}

#[test]
fn test_epub_with_uppercase_meta_inf_directory_is_rejected() {
    // `META-INF/container.xml` is also an exact, case-sensitive OCF path.
    let epub = create_epub_with_named_container_entries(
        Some("mimetype"),
        "META-INF/CONTAINER.XML",
        MINIMAL_EPUB_OPF,
        b"<html><body><p>Chapter</p></body></html>",
    );

    let error = glibusta_core::book::epub::parse_epub(&epub, None)
        .expect_err("non-canonical META-INF path must not be accepted as EPUB");

    assert!(error.to_string().contains("META-INF/container.xml"));
}

#[test]
fn test_epub_with_non_opf_package_document_is_rejected() {
    let error = glibusta_core::book::epub::parse_epub(
        &create_epub_with_opf(true, b"<?xml version=\"1.0\"?><not-an-opf/>"),
        None,
    )
    .expect_err("a non-OPF package document must not be accepted");

    assert!(error.to_string().contains("OPF"));
}

// ---------------------------------------------------------------------------
// DOCX tests — minimal in-memory DOCX
// ---------------------------------------------------------------------------

fn create_minimal_docx() -> Vec<u8> {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);

    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);

    zip.start_file("docProps/core.xml", options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"
  xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>DOCX Title</dc:title>
  <dc:creator>Author Name</dc:creator>
</cp:coreProperties>"#,
    )
    .unwrap();

    zip.start_file("word/document.xml", options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0" encoding="utf-8"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr><w:pStyle w:val="Title"/></w:pPr>
      <w:r><w:t>Document Title</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>First paragraph.</w:t></w:r>
    </w:p>
    <w:p>
      <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
      <w:r><w:rPr><w:b/></w:rPr><w:t>Bold Heading</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>Second paragraph with </w:t></w:r>
      <w:r><w:rPr><w:i/></w:rPr><w:t>italic text</w:t></w:r>
    </w:p>
  </w:body>
</w:document>"#,
    )
    .unwrap();

    // Minimal 1×1 transparent PNG
    zip.start_file("word/media/image1.png", options).unwrap();
    zip.write_all(&[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    ])
    .unwrap();

    zip.finish().unwrap();
    buf.into_inner()
}

#[test]
fn test_docx_basic_parse() {
    let docx_bytes = create_minimal_docx();
    let book = glibusta_core::book::docx::parse_docx(&docx_bytes, None).unwrap();
    assert_eq!(book.title, "DOCX Title");
    assert_eq!(book.authors, vec!["Author Name"]);
    assert_eq!(book.book_format, BookFormat::Docx);
}

#[test]
fn test_docx_embedded_images() {
    let docx_bytes = create_minimal_docx();
    let book = glibusta_core::book::docx::parse_docx(&docx_bytes, None).unwrap();
    assert_eq!(book.images.len(), 1, "should extract 1 image");
    assert_eq!(book.images[0].id, "image1.png");
    assert_eq!(book.images[0].media_type, "image/png");
    assert!(
        book.cover_url.is_some(),
        "first image should become cover_url"
    );
}

#[test]
fn test_docx_paragraphs() {
    let docx_bytes = create_minimal_docx();
    let book = glibusta_core::book::docx::parse_docx(&docx_bytes, None).unwrap();
    assert!(!book.chapters.is_empty(), "should have a chapter");
    let blocks = &book.chapters[0].blocks;
    assert!(
        blocks.len() >= 3,
        "should have at least 3 blocks, got {}",
        blocks.len()
    );
}

// ---------------------------------------------------------------------------
// RTF tests
// ---------------------------------------------------------------------------

#[test]
fn test_rtf_basic_parse() {
    let rtf_text = br"{\rtf1\ansi\deff0
{\fonttbl {\f0 Times New Roman;}}
\f0\fs24{\b Chapter 1}\par
Hello, world!\par
This is a second paragraph.\par
}";
    let book = glibusta_core::book::rtf::parse_rtf(rtf_text, None).unwrap();
    assert_eq!(book.book_format, BookFormat::Rtf);
    assert!(!book.chapters.is_empty(), "should have chapters");
    let blocks = &book.chapters[0].blocks;
    assert!(!blocks.is_empty(), "should have blocks");
    assert!(
        blocks.iter().any(|b| b.text.contains("Hello")),
        "should contain 'Hello' text"
    );
}

// ---------------------------------------------------------------------------
// Edge case tests
// ---------------------------------------------------------------------------

#[test]
fn test_book_format_from_ext() {
    assert_eq!(BookFormat::from_ext("fb2"), BookFormat::Fb2);
    assert_eq!(BookFormat::from_ext("zip"), BookFormat::Fb2);
    assert_eq!(BookFormat::from_ext("ePuB"), BookFormat::Epub);
    assert_eq!(BookFormat::from_ext("TXT"), BookFormat::Txt);
    assert_eq!(BookFormat::from_ext("docx"), BookFormat::Docx);
    assert_eq!(BookFormat::from_ext("docm"), BookFormat::Docx);
    assert_eq!(BookFormat::from_ext("mobi"), BookFormat::Mobi);
    assert_eq!(BookFormat::from_ext("pdf"), BookFormat::Pdf);
    assert_eq!(BookFormat::from_ext("djvu"), BookFormat::Djvu);
    assert_eq!(BookFormat::from_ext("CBR"), BookFormat::Cbr);
    assert_eq!(BookFormat::from_ext("unknown"), BookFormat::Unknown);
}

#[test]
fn test_normalized_book_json_roundtrip() {
    let book = NormalizedBook {
        id: "test123".into(),
        title: "Test".into(),
        authors: vec!["Author".into()],
        description: Some("Desc".into()),
        cover_url: None,
        chapters: vec![ReaderChapter {
            index: 0,
            title: "Ch 1".into(),
            blocks: vec![ReaderBlock {
                index: 0,
                text: "Hello".into(),
                block_type: BlockType::Paragraph,
                image_url: None,
                note_ref: None,
                rich_spans: None,
                heading_level: None,
                ordered: None,
                list_items: None,
                table_rows: None,
                image_alt: None,
                text_indent: None,
                text_align: None,
                note_id: None,
            }],
        }],
        metadata: None,
        book_format: BookFormat::Fb2,
        language: Some("ru".into()),
        warnings: vec![],
        images: vec![],
        toc: vec![TocEntry {
            title: "Ch 1".into(),
            chapter_index: 0,
            children: vec![],
        }],
    };

    let json = book.to_json_string().unwrap();
    let restored = NormalizedBook::from_json_str(&json).unwrap();
    assert_eq!(restored.id, book.id);
    assert_eq!(restored.title, book.title);
    assert_eq!(restored.book_format, book.book_format);
    assert_eq!(restored.language, book.language);
    assert_eq!(restored.toc.len(), 1);
}

// ---------------------------------------------------------------------------
// Golden tests — snapshot-based regression detection
// ---------------------------------------------------------------------------

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_fb2_golden_snapshot() {
    let book = glibusta_core::book::fb2::parse_fb2(MINIMAL_FB2.as_bytes(), None).unwrap();
    let snapshot = serde_json::json!({
        "title": book.title,
        "authors": book.authors,
        "language": book.language,
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "chapter_titles": book.chapters.iter().map(|c| c.title.as_str()).collect::<Vec<_>>(),
        "blocks_per_chapter": book.chapters.iter().map(|c| c.blocks.len()).collect::<Vec<_>>(),
        "toc": book.toc.iter().map(|t| t.title.as_str()).collect::<Vec<_>>(),
    });
    insta::assert_snapshot!("fb2_golden", snapshot.to_string());
}

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_txt_golden_snapshot() {
    let txt = "Первая строка\n\nВторая строка\n\nТретий абзац текста.";
    let book = glibusta_core::book::txt::parse_txt(txt.as_bytes(), None).unwrap();
    let snapshot = serde_json::json!({
        "title": book.title,
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "blocks": book.chapters.iter().map(|c| c.blocks.len()).sum::<usize>(),
        "toc": book.toc.iter().map(|t| t.title.as_str()).collect::<Vec<_>>(),
    });
    insta::assert_snapshot!("txt_golden", snapshot.to_string());
}

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_rtf_golden_snapshot() {
    let rtf = br"{\rtf1\ansi\deff0
{\fonttbl {\f0 Times New Roman;}}
\f0\fs24{\b Chapter 1}\par
Hello, world!\par
}";
    let book = glibusta_core::book::rtf::parse_rtf(rtf, None).unwrap();
    let snapshot = serde_json::json!({
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "blocks": book.chapters.iter().map(|c| c.blocks.len()).sum::<usize>(),
    });
    insta::assert_snapshot!("rtf_golden", snapshot.to_string());
}

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_epub_golden_snapshot() {
    let epub_bytes = create_minimal_epub();
    let book = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    let snapshot = serde_json::json!({
        "title": book.title,
        "authors": book.authors,
        "language": book.language,
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "chapter_titles": book.chapters.iter().map(|c| c.title.as_str()).collect::<Vec<_>>(),
        "toc": book.toc.iter().map(|t| t.title.as_str()).collect::<Vec<_>>(),
        "warnings": book.warnings.iter().map(|w| w.message.as_str()).collect::<Vec<_>>(),
    });
    insta::assert_snapshot!("epub_golden", snapshot.to_string());
}

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_docx_golden_snapshot() {
    let docx_bytes = create_minimal_docx();
    let book = glibusta_core::book::docx::parse_docx(&docx_bytes, None).unwrap();
    let snapshot = serde_json::json!({
        "title": book.title,
        "authors": book.authors,
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "images": book.images.len(),
    });
    insta::assert_snapshot!("docx_golden", snapshot.to_string());
}

// ---------------------------------------------------------------------------
// RCE-26: Parse performance benchmarks
// ---------------------------------------------------------------------------

#[test]
#[cfg_attr(miri, ignore)] // timing tests are meaningless under Miri
fn test_parse_metadata_under_300ms() {
    let epub_bytes = create_minimal_epub();
    let start = std::time::Instant::now();
    for _ in 0..100 {
        let _ = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    }
    let elapsed_ms = start.elapsed().as_millis();
    assert!(
        elapsed_ms < 300,
        "100 EPUB parses took {}ms (>300ms budget)",
        elapsed_ms
    );
}

#[test]
#[cfg_attr(miri, ignore)] // timing tests are meaningless under Miri
fn test_fb2_parse_under_3s() {
    let start = std::time::Instant::now();
    for _ in 0..10 {
        let _ = glibusta_core::book::fb2::parse_fb2(MINIMAL_FB2.as_bytes(), None).unwrap();
    }
    let elapsed_ms = start.elapsed().as_millis();
    assert!(
        elapsed_ms < 3000,
        "10 FB2 parses took {}ms (>3s budget)",
        elapsed_ms
    );
}

#[test]
#[cfg_attr(miri, ignore)] // timing tests are meaningless under Miri
fn test_parse_toc_under_500ms() {
    let epub_bytes = create_minimal_epub();
    let start = std::time::Instant::now();
    for _ in 0..100 {
        let _ = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    }
    let elapsed_ms = start.elapsed().as_millis();
    assert!(
        elapsed_ms < 500,
        "100 EPUB TOC parses took {}ms (>500ms budget)",
        elapsed_ms
    );
}

#[test]
#[cfg_attr(miri, ignore)] // timing tests are meaningless under Miri
fn test_parse_chapter_under_200ms() {
    let epub_bytes = create_minimal_epub();
    let start = std::time::Instant::now();
    for _ in 0..100 {
        let book = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
        let _ = book.chapters.first().unwrap();
    }
    let elapsed_ms = start.elapsed().as_millis();
    assert!(
        elapsed_ms < 200,
        "100 chapter extractions took {}ms (>200ms budget)",
        elapsed_ms
    );
}

// ---------------------------------------------------------------------------
// RCE-13: Corpus — edge case tests
// ---------------------------------------------------------------------------

#[test]
fn test_txt_empty_file() {
    let book = glibusta_core::book::txt::parse_txt(b"", None).unwrap();
    assert_eq!(book.title, "");
    assert!(book.chapters.is_empty() || book.chapters[0].blocks.is_empty());
}

#[test]
fn test_txt_single_line() {
    let book = glibusta_core::book::txt::parse_txt(b"Hello, world!", None).unwrap();
    assert!(!book.chapters.is_empty());
    assert!(!book.chapters[0].blocks.is_empty());
}

#[test]
fn test_fb2_malformed_xml() {
    let bad_fb2 = b"<?xml version=\"1.0\"?><FictionBook><title>Test</title></FictionBook>";
    let result = glibusta_core::book::fb2::parse_fb2(bad_fb2, None);
    assert!(
        result.is_err(),
        "schema-invalid FB2 must return a controlled error"
    );
}

#[test]
fn test_txt_cp1251_encoding() {
    // "Привет" in Windows-1251
    let text = b"\xcf\xf0\xe8\xe2\xe5\xf2";
    let book = glibusta_core::book::txt::parse_txt(text, Some("windows-1251")).unwrap();
    assert!(!book.chapters.is_empty());
    assert!(!book.chapters[0].blocks.is_empty());
    assert!(book.chapters[0].blocks[0].text.contains("Привет"));
}

#[test]
fn test_docx_empty() {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);
    let options =
        zip::write::FileOptions::<()>::default().compression_method(zip::CompressionMethod::Stored);
    zip.start_file("[Content_Types].xml", options).unwrap();
    zip.write_all(b"<?xml version=\"1.0\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/></Types>").unwrap();
    zip.start_file("word/document.xml", options).unwrap();
    zip.write_all(b"<?xml version=\"1.0\"?>\n<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body/></w:document>").unwrap();
    zip.start_file("docProps/core.xml", options).unwrap();
    zip.write_all(b"<?xml version=\"1.0\"?>\n<cp:coreProperties xmlns:cp=\"http://schemas.openxmlformats.org/package/2006/metadata/core-properties\"/>").unwrap();
    zip.finish().unwrap();
    let bytes = buf.into_inner();
    let book = glibusta_core::book::docx::parse_docx(&bytes, None).unwrap();
    assert_eq!(book.title, "");
    assert!(book.chapters.is_empty() || book.chapters[0].blocks.is_empty());
}

#[test]
fn test_rtf_empty() {
    let book = glibusta_core::book::rtf::parse_rtf(b"", None).unwrap();
    assert_eq!(book.book_format, BookFormat::Rtf);
}

#[test]
fn test_fb2_empty_body() {
    let fb2 = br#"<?xml version="1.0" encoding="utf-8"?>
<FictionBook xmlns="http://www.gribuser.ru/xml/fictionbook/2.0">
  <description>
    <title-info><book-title>Empty</book-title><lang>en</lang></title-info>
  </description>
  <body><section/></body>
</FictionBook>"#;
    let book = glibusta_core::book::fb2::parse_fb2(fb2, None).unwrap();
    assert_eq!(book.title, "Empty");
}

// ---------------------------------------------------------------------------
// MOBI — minimal in-memory fixture + golden test
// ---------------------------------------------------------------------------

fn create_mobi_with_text(text: &[u8]) -> Vec<u8> {
    let text_len = text.len() as u32;

    let record0_offset = 94u32; // 78 header + 16 record table
    let record0_size = 248u32; // 16 PalmDOC + 232 MOBI header
    let record1_offset = record0_offset + record0_size;

    let mut buf = Vec::with_capacity(record1_offset as usize + text.len());

    // PalmDB header (78 bytes)
    buf.extend_from_slice(b"Test MOBI");
    buf.resize(32, 0); // name = 32 bytes
    buf.extend_from_slice(&[0; 2]); // attributes
    buf.extend_from_slice(&[0; 2]); // version
    buf.extend_from_slice(&[0; 4]); // creation time
    buf.extend_from_slice(&[0; 4]); // modification time
    buf.extend_from_slice(&[0; 4]); // backup time
    buf.extend_from_slice(&[0; 4]); // modification number
    buf.extend_from_slice(&[0; 4]); // app info area
    buf.extend_from_slice(&[0; 4]); // sort info area
    buf.extend_from_slice(b"BOOK"); // type
    buf.extend_from_slice(b"MOBI"); // creator
    buf.extend_from_slice(&[0; 4]); // unique ID seed
    buf.extend_from_slice(&[0; 4]); // next record list ID
    assert_eq!(buf.len(), 76);
    buf.extend_from_slice(&2u16.to_be_bytes()); // num_records = 2
    assert_eq!(buf.len(), 78);

    // Record table (2 entries × 8 bytes = 16 bytes, starts at offset 78)
    buf.extend_from_slice(&record0_offset.to_be_bytes()); // record 0 offset
    buf.extend_from_slice(&[0, 0, 0, 0]); // attr + unique_id
    buf.extend_from_slice(&record1_offset.to_be_bytes()); // record 1 offset
    buf.extend_from_slice(&[0, 0, 0, 1]); // attr + unique_id
    assert_eq!(buf.len(), 94);

    // Record 0: PalmDOC header (16 bytes)
    let r0 = buf.len();
    buf.extend_from_slice(&1u16.to_be_bytes()); // compression = 1 (none)
    buf.extend_from_slice(&0u16.to_be_bytes()); // unused
    buf.extend_from_slice(&text_len.to_be_bytes()); // text_length
    buf.extend_from_slice(&1u16.to_be_bytes()); // text_record_count = 1
    buf.extend_from_slice(&4096u16.to_be_bytes()); // record_size
    buf.extend_from_slice(&0u16.to_be_bytes()); // encryption = 0
    buf.extend_from_slice(&0u16.to_be_bytes()); // unused
    assert_eq!(buf.len(), r0 + 16);

    // Record 0: MOBI header (232 bytes)
    let mobi = r0 + 16;
    buf.extend_from_slice(b"MOBI");
    buf.extend_from_slice(&232u32.to_be_bytes()); // header_length
    buf.resize(mobi + 232, 0); // zero-fill rest of MOBI header
    // Set text_encoding = 1252 at mobi+12
    buf[mobi + 12..mobi + 14].copy_from_slice(&1252u16.to_be_bytes());

    // Record 1: HTML text
    assert_eq!(buf.len(), record1_offset as usize);
    buf.extend_from_slice(text);

    buf
}

fn create_minimal_mobi() -> Vec<u8> {
    create_mobi_with_text(b"<html><body><p>Hello MOBI</p><p>Second paragraph.</p></body></html>")
}

fn create_mobi_header_record(
    text_length: u32,
    text_record_count: u16,
    exth_records: &[(u32, Vec<u8>)],
) -> Vec<u8> {
    let mut record = vec![0; 248];
    record[0..2].copy_from_slice(&1u16.to_be_bytes()); // PalmDOC compression = none
    record[4..8].copy_from_slice(&text_length.to_be_bytes());
    record[8..10].copy_from_slice(&text_record_count.to_be_bytes());
    record[10..12].copy_from_slice(&4096u16.to_be_bytes());
    record[16..20].copy_from_slice(b"MOBI");
    record[20..24].copy_from_slice(&232u32.to_be_bytes());
    record[28..30].copy_from_slice(&1252u16.to_be_bytes());

    if !exth_records.is_empty() {
        record[16 + 128..16 + 132].copy_from_slice(&0x40u32.to_be_bytes());
        let exth_len = 12
            + exth_records
                .iter()
                .map(|(_, data)| 8 + data.len())
                .sum::<usize>();
        record.extend_from_slice(b"EXTH");
        record.extend_from_slice(&(exth_len as u32).to_be_bytes());
        record.extend_from_slice(&(exth_records.len() as u32).to_be_bytes());
        for (kind, data) in exth_records {
            record.extend_from_slice(&kind.to_be_bytes());
            record.extend_from_slice(&((8 + data.len()) as u32).to_be_bytes());
            record.extend_from_slice(data);
        }
    }

    record
}

fn create_palm_mobi(records: Vec<Vec<u8>>) -> Vec<u8> {
    let table_end = 78 + records.len() * 8;
    let mut offsets = Vec::with_capacity(records.len());
    let mut next_offset = table_end;
    for record in &records {
        offsets.push(next_offset as u32);
        next_offset += record.len();
    }

    let mut bytes = Vec::with_capacity(next_offset);
    bytes.extend_from_slice(b"Dual MOBI");
    bytes.resize(32, 0);
    bytes.resize(76, 0);
    bytes[60..64].copy_from_slice(b"BOOK");
    bytes[64..68].copy_from_slice(b"MOBI");
    bytes.extend_from_slice(&(records.len() as u16).to_be_bytes());
    for (index, offset) in offsets.iter().enumerate() {
        bytes.extend_from_slice(&offset.to_be_bytes());
        bytes.extend_from_slice(&[0, 0, 0, index as u8]);
    }
    for record in records {
        bytes.extend_from_slice(&record);
    }
    bytes
}

fn create_dual_format_mobi() -> Vec<u8> {
    // EXTH 121 points at the BOUNDARY record (record 2). The following record
    // is the KF8 header and its text starts at record 4.
    let legacy_text = b"<p>Legacy KF7 text</p>";
    let kf8_text = b"<p>Modern KF8 text</p>";
    let legacy_header = create_mobi_header_record(
        legacy_text.len() as u32,
        1,
        &[(121, 2u32.to_be_bytes().to_vec())],
    );
    let kf8_header = create_mobi_header_record(kf8_text.len() as u32, 1, &[]);
    create_palm_mobi(vec![
        legacy_header,
        legacy_text.to_vec(),
        b"BOUNDARY".to_vec(),
        kf8_header,
        kf8_text.to_vec(),
    ])
}

fn create_mobi_with_invalid_kf8_boundary() -> Vec<u8> {
    let text = b"<p>Readable legacy text</p>";
    let legacy_header =
        create_mobi_header_record(text.len() as u32, 1, &[(121, 2u32.to_be_bytes().to_vec())]);
    create_palm_mobi(vec![
        legacy_header,
        text.to_vec(),
        b"not a KF8 boundary".to_vec(),
    ])
}

fn create_mobi_with_inline_image(recindex: u32) -> Vec<u8> {
    let text = format!(
        "<p>Before illustration</p><img recindex=\"{recindex}\" alt=\"Map\"/><p>After illustration</p>"
    );
    let mut header = create_mobi_header_record(text.len() as u32, 1, &[]);
    // MOBI record indexes are absolute PalmDB record indexes. The first image
    // follows record 0 (header) and record 1 (text) in this fixture.
    header[16 + 108..16 + 112].copy_from_slice(&2u32.to_be_bytes());
    create_palm_mobi(vec![
        header,
        text.into_bytes(),
        b"\x89PNG\r\n\x1a\ninline-image".to_vec(),
        b"GIF89asecond-image".to_vec(),
    ])
}

fn create_mobi_with_extra_record_data() -> Vec<u8> {
    let mut header = create_mobi_header_record(4100, 2, &[]);
    header[28..30].copy_from_slice(&65001u16.to_be_bytes());
    // Extra Record Data Flags live at record-0 offset 0xf0 (MOBI header + 224).
    // Bit 0 carries UTF-8 overlap bytes; bit 1 carries a size-delimited index
    // entry that must be peeled first while walking backwards.
    header[16 + 224..16 + 228].copy_from_slice(&3u32.to_be_bytes());

    let mut first_record = vec![b'a'; 4095];
    first_record.push(0xF0); // First byte of 😀.
    first_record.extend_from_slice(&[0x9F, 0x98, 0x80, 0x03]); // overlap + count
    first_record.extend_from_slice(&[0x55, 0x82]); // index data + backward VWI size=2

    create_palm_mobi(vec![
        header,
        first_record,
        vec![0x9F, 0x98, 0x80, b'b', 0x00, 0x55, 0x82],
    ])
}

#[test]
fn test_mobi_basic_parse() {
    let mobi_bytes = create_minimal_mobi();
    let book = glibusta_core::book::mobi::parse_mobi(&mobi_bytes, None).unwrap();
    assert!(!book.chapters.is_empty(), "should have chapters");
    assert!(!book.chapters[0].blocks.is_empty(), "should have blocks");
    assert_eq!(book.book_format, BookFormat::Mobi);
}

#[test]
fn test_mobi_resolves_inline_recindex_images() {
    let book = glibusta_core::book::mobi::parse_mobi(&create_mobi_with_inline_image(1), None)
        .expect("parse MOBI with inline image");
    let image = book.chapters[0]
        .blocks
        .iter()
        .find(|block| block.block_type == BlockType::Image)
        .expect("inline recindex image block");

    assert_eq!(image.image_alt.as_deref(), Some("Map"));
    assert_eq!(
        image.image_url.as_deref(),
        Some("data:image/png;base64,iVBORw0KGgppbmxpbmUtaW1hZ2U="),
    );
}

#[test]
fn test_mobi_recindex_is_relative_to_first_image_record() {
    let book = glibusta_core::book::mobi::parse_mobi(&create_mobi_with_inline_image(2), None)
        .expect("parse MOBI with a second inline image resource");
    let image = book.chapters[0]
        .blocks
        .iter()
        .find(|block| block.block_type == BlockType::Image)
        .expect("inline recindex image block");

    assert_eq!(
        image.image_url.as_deref(),
        Some("data:image/gif;base64,R0lGODlhc2Vjb25kLWltYWdl"),
    );
}

#[test]
fn test_mobi_strips_extra_record_data_before_utf8_decode() {
    let book = glibusta_core::book::mobi::parse_mobi(&create_mobi_with_extra_record_data(), None)
        .expect("parse MOBI with trailing metadata and split UTF-8 character");
    let text = book.chapters[0]
        .blocks
        .iter()
        .map(|block| block.text.as_str())
        .collect::<String>();

    assert_eq!(text, format!("{}😀b", "a".repeat(4095)));
    assert!(text.ends_with("😀b"));
    assert!(!text.contains('\u{3}'));
}

#[test]
fn test_mobi_rejects_malformed_extra_record_data() {
    let mut mobi = create_mobi_with_extra_record_data();
    let first_text_offset = u32::from_be_bytes([mobi[86], mobi[87], mobi[88], mobi[89]]) as usize;
    let second_text_offset = u32::from_be_bytes([mobi[94], mobi[95], mobi[96], mobi[97]]) as usize;
    // Bit 1 requires a backward VWI. Make its terminal byte non-terminal so
    // the parser cannot derive a bounded entry size.
    mobi[second_text_offset - 1] = 0x01;
    assert!(second_text_offset > first_text_offset);

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("malformed trailing entry must be rejected before decompression");

    assert!(error.to_string().contains("trailing entry"));
}

#[test]
fn test_mobi_corruption_regression_corpus_has_controlled_outcomes() {
    // PalmDB offsets must remain ordered and inside the input.  Use three
    // records so the third offset can be in range yet still regress.
    let text = b"<p>Corpus text</p>";
    let mut unsorted_offsets = create_palm_mobi(vec![
        create_mobi_header_record(text.len() as u32, 1, &[]),
        text.to_vec(),
        b"unused resource".to_vec(),
    ]);
    let second_offset = u32::from_be_bytes([
        unsorted_offsets[86],
        unsorted_offsets[87],
        unsorted_offsets[88],
        unsorted_offsets[89],
    ]);
    unsorted_offsets[94..98].copy_from_slice(&second_offset.saturating_sub(1).to_be_bytes());
    let error = glibusta_core::book::mobi::parse_mobi(&unsorted_offsets, None)
        .expect_err("an in-range but unsorted PalmDB offset must be rejected");
    assert!(error.to_string().contains("not sorted"));

    let mut out_of_range_offset = create_minimal_mobi();
    out_of_range_offset[78..82].copy_from_slice(&u32::MAX.to_be_bytes());
    let error = glibusta_core::book::mobi::parse_mobi(&out_of_range_offset, None)
        .expect_err("an out-of-range PalmDB offset must be rejected");
    assert!(error.to_string().contains("record offset"));

    // EXTH metadata is optional: a corrupt declared length must degrade to
    // base MOBI metadata without affecting the verified text stream.
    let mut exth_header = create_mobi_header_record(
        text.len() as u32,
        1,
        &[(503, b"Corrupt optional title".to_vec())],
    );
    let exth_offset = exth_header
        .windows(4)
        .position(|window| window == b"EXTH")
        .expect("fixture contains EXTH");
    exth_header[exth_offset + 4..exth_offset + 8].copy_from_slice(&u32::MAX.to_be_bytes());
    let book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![exth_header, text.to_vec()]),
        None,
    )
    .expect("malformed optional EXTH must not crash or discard readable text");
    assert_eq!(book.chapters[0].blocks[0].text, "Corpus text");

    let record_count_error = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![
            create_mobi_header_record(4097, 1, &[]),
            vec![b'x'; 4096],
        ]),
        None,
    )
    .expect_err("inconsistent PalmDOC record count must be rejected");
    assert!(record_count_error.to_string().contains("record count"));

    let mut unsupported_compression = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([
        unsupported_compression[78],
        unsupported_compression[79],
        unsupported_compression[80],
        unsupported_compression[81],
    ]) as usize;
    unsupported_compression[record0_offset..record0_offset + 2]
        .copy_from_slice(&17480u16.to_be_bytes());
    let error = glibusta_core::book::mobi::parse_mobi(&unsupported_compression, None)
        .expect_err("unsupported compression must be rejected before decoding");
    assert!(error.to_string().contains("Unsupported MOBI compression"));

    let mut malformed_vwi = create_mobi_with_extra_record_data();
    let second_text_offset = u32::from_be_bytes([
        malformed_vwi[94],
        malformed_vwi[95],
        malformed_vwi[96],
        malformed_vwi[97],
    ]) as usize;
    malformed_vwi[second_text_offset - 1] = 0x01;
    let error = glibusta_core::book::mobi::parse_mobi(&malformed_vwi, None)
        .expect_err("malformed extra-data VWI must be rejected before decompression");
    assert!(error.to_string().contains("trailing entry"));
}

#[test]
fn test_mobi_ignores_optional_audio_and_video_records_after_text() {
    let text = b"<p>Readable MOBI text</p>";
    let mobi = create_palm_mobi(vec![
        create_mobi_header_record(text.len() as u32, 1, &[]),
        text.to_vec(),
        b"AUDI\0\xFFnot a text record".to_vec(),
        b"VIDE\0\xFFnot an image record".to_vec(),
    ]);

    let book = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect("optional media records after the declared text stream must be ignored");
    let parsed_text = book
        .chapters
        .iter()
        .flat_map(|chapter| &chapter.blocks)
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert_eq!(parsed_text, "Readable MOBI text");
    assert!(!parsed_text.contains("AUDI"));
    assert!(!parsed_text.contains("VIDE"));
    assert!(book.images.is_empty());
}

#[test]
fn test_mobi_ignores_optional_and_unknown_records_after_text() {
    let text = b"<p>The only MOBI text record</p>";
    let mobi = create_palm_mobi(vec![
        create_mobi_header_record(text.len() as u32, 1, &[]),
        text.to_vec(),
        Vec::new(), // optional zero record
        b"FLIS\0\xFFcontrol data".to_vec(),
        b"FCIS\0\xFFcontrol data".to_vec(),
        b"EOF\0\xFFcontrol data".to_vec(),
        b"SRCS\0\xFFsource data".to_vec(),
        b"CMET\0\xFFcompilation metadata".to_vec(),
        b"UNKN\0\xFFnon-book record".to_vec(),
    ]);

    let book = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect("optional records outside the declared text range must be ignored");
    let parsed_text = book
        .chapters
        .iter()
        .flat_map(|chapter| &chapter.blocks)
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert_eq!(parsed_text, "The only MOBI text record");
    assert!(book.images.is_empty());
}

#[test]
fn test_mobi_decodes_cp1252_text_title_and_exth_language() {
    let text = b"<p>Le caf\xE9</p>";
    let mut header = create_mobi_header_record(
        text.len() as u32,
        1,
        &[(503, b"Le caf\xE9".to_vec()), (524, b"fr".to_vec())],
    );
    header[28..30].copy_from_slice(&1252u16.to_be_bytes());

    let book =
        glibusta_core::book::mobi::parse_mobi(&create_palm_mobi(vec![header, text.to_vec()]), None)
            .expect("CP1252 MOBI metadata and text must decode");

    assert_eq!(book.title, "Le café");
    assert_eq!(book.language.as_deref(), Some("fr"));
    assert_eq!(book.chapters[0].blocks[0].text, "Le café");

    let mut full_name_mobi = create_mobi_with_text(text);
    let record0_offset = u32::from_be_bytes([
        full_name_mobi[78],
        full_name_mobi[79],
        full_name_mobi[80],
        full_name_mobi[81],
    ]) as usize;
    let mobi_offset = record0_offset + 16;
    full_name_mobi[mobi_offset + 84..mobi_offset + 88].copy_from_slice(&220u32.to_be_bytes());
    full_name_mobi[mobi_offset + 88..mobi_offset + 92]
        .copy_from_slice(&(b"Le caf\xE9".len() as u32).to_be_bytes());
    full_name_mobi[record0_offset + 220..record0_offset + 227].copy_from_slice(b"Le caf\xE9");

    let full_name_book = glibusta_core::book::mobi::parse_mobi(&full_name_mobi, None)
        .expect("CP1252 Full Name must decode");
    assert_eq!(full_name_book.title, "Le café");
}

#[test]
fn test_mobi_preserves_raw_locale_fields_without_inventing_a_bcp47_mapping() {
    let text = b"<p>Locale fixture</p>";
    let mut header = create_mobi_header_record(text.len() as u32, 1, &[(524, b"en-GB".to_vec())]);
    // MOBI header offsets are relative to its magic at record-0 offset 16:
    // 0x5c locale, 0x60 dictionary input locale, 0x64 dictionary output locale.
    header[16 + 92..16 + 96].copy_from_slice(&2057u32.to_be_bytes());
    header[16 + 96..16 + 100].copy_from_slice(&1033u32.to_be_bytes());
    header[16 + 100..16 + 104].copy_from_slice(&1036u32.to_be_bytes());

    let book =
        glibusta_core::book::mobi::parse_mobi(&create_palm_mobi(vec![header, text.to_vec()]), None)
            .expect("MOBI locale fields must not affect decoding");

    // EXTH 524 is already a textual language tag and is therefore the only
    // locale-related value suitable for NormalizedBook.language.
    assert_eq!(book.language.as_deref(), Some("en-GB"));
    let metadata = book.metadata.expect("MOBI metadata");
    assert_eq!(metadata["mobiLocale"], 2057);
    assert_eq!(metadata["mobiInputLanguage"], 1033);
    assert_eq!(metadata["mobiOutputLanguage"], 1036);
}

#[test]
fn test_mobi_preserves_repeated_exth_authors_and_subjects_with_metadata() {
    let text = b"<p>EXTH metadata fixture</p>";
    let book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![
            create_mobi_header_record(
                text.len() as u32,
                1,
                &[
                    (100, b"Alice Author".to_vec()),
                    (100, b"Bob Author".to_vec()),
                    (101, b"Test Publisher".to_vec()),
                    (103, b"Validated description".to_vec()),
                    (104, b"978-1-234567-89-7".to_vec()),
                    (105, b"Fiction".to_vec()),
                    (105, b"Adventure".to_vec()),
                    (524, b"en".to_vec()),
                ],
            ),
            text.to_vec(),
        ]),
        None,
    )
    .expect("valid repeated EXTH records must parse");

    assert_eq!(book.authors, ["Alice Author", "Bob Author"]);
    assert_eq!(book.description.as_deref(), Some("Validated description"));
    assert_eq!(book.language.as_deref(), Some("en"));
    let metadata = book.metadata.expect("MOBI metadata");
    assert_eq!(metadata["mobiPublisher"], "Test Publisher");
    assert_eq!(metadata["mobiIsbn"], "978-1-234567-89-7");
    assert_eq!(
        metadata["mobiSubjects"],
        serde_json::json!(["Fiction", "Adventure"])
    );
}

#[test]
fn test_mobi_decodes_utf8_and_falls_back_safely_for_unknown_code_pages() {
    let text = "<p>Привет</p>".as_bytes().to_vec();
    let mut utf8_header = create_mobi_header_record(
        text.len() as u32,
        1,
        &[(503, "Книга".as_bytes().to_vec()), (524, b"ru".to_vec())],
    );
    utf8_header[28..30].copy_from_slice(&65001u16.to_be_bytes());

    let utf8_book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![utf8_header, text.clone()]),
        None,
    )
    .expect("UTF-8 MOBI metadata and text must decode");
    assert_eq!(utf8_book.title, "Книга");
    assert_eq!(utf8_book.language.as_deref(), Some("ru"));
    assert_eq!(utf8_book.chapters[0].blocks[0].text, "Привет");

    let mut unknown_encoding_header = create_mobi_header_record(
        text.len() as u32,
        1,
        &[(503, "Запасной заголовок".as_bytes().to_vec())],
    );
    unknown_encoding_header[28..30].copy_from_slice(&u16::MAX.to_be_bytes());
    let fallback_book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![unknown_encoding_header, text]),
        None,
    )
    .expect("an unknown code page must use the controlled UTF-8 fallback");
    assert_eq!(fallback_book.title, "Запасной заголовок");
    assert_eq!(fallback_book.chapters[0].blocks[0].text, "Привет");

    // An unknown code page must not leave a rare invalid UTF-8 byte as U+FFFD
    // just because the surrounding ASCII text happens to be long.
    let mut cp1252_text = format!("<p>{}caf", "plain ".repeat(24)).into_bytes();
    cp1252_text.push(0xE9);
    cp1252_text.extend_from_slice(b"</p>");
    let mut cp1252_title = format!("{}caf", "plain ".repeat(24)).into_bytes();
    cp1252_title.push(0xE9);
    let mut cp1252_header =
        create_mobi_header_record(cp1252_text.len() as u32, 1, &[(503, cp1252_title)]);
    cp1252_header[28..30].copy_from_slice(&u16::MAX.to_be_bytes());
    let cp1252_fallback = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![cp1252_header, cp1252_text]),
        None,
    )
    .expect("an unknown code page must fall back to CP1252 for invalid UTF-8");
    assert!(cp1252_fallback.title.ends_with("café"));
    assert!(cp1252_fallback.chapters[0].blocks[0].text.ends_with("café"));
}

#[test]
fn test_mobi_decodes_utf16_text_and_exth_metadata() {
    fn utf16(text: &str, little_endian: bool, include_bom: bool) -> Vec<u8> {
        let mut bytes = if include_bom && little_endian {
            vec![0xFF, 0xFE]
        } else if include_bom {
            vec![0xFE, 0xFF]
        } else {
            Vec::new()
        };
        for unit in text.encode_utf16() {
            let encoded = if little_endian {
                unit.to_le_bytes()
            } else {
                unit.to_be_bytes()
            };
            bytes.extend_from_slice(&encoded);
        }
        bytes
    }

    for little_endian in [true, false] {
        let text = utf16("<p>Привет 😀</p>", little_endian, true);
        let title = utf16("Книга", little_endian, true);
        let mut header = create_mobi_header_record(text.len() as u32, 1, &[(503, title)]);
        header[28..30].copy_from_slice(&65002u16.to_be_bytes());

        let book =
            glibusta_core::book::mobi::parse_mobi(&create_palm_mobi(vec![header, text]), None)
                .expect("BOM-marked UTF-16 MOBI text and EXTH metadata must decode");
        assert_eq!(book.title, "Книга");
        assert_eq!(book.chapters[0].blocks[0].text, "Привет 😀");
    }

    // MOBI's UTF-16 code page permits BOM-less content. This must be decoded
    // as a u16 sequence, not one code unit at a time: the latter drops both
    // halves of the supplementary scalar below.
    let text = utf16("<p>Привет 😀</p>", true, false);
    let title = utf16("Книга 😀", true, false);
    let mut header = create_mobi_header_record(text.len() as u32, 1, &[(503, title)]);
    header[28..30].copy_from_slice(&65002u16.to_be_bytes());

    let book = glibusta_core::book::mobi::parse_mobi(&create_palm_mobi(vec![header, text]), None)
        .expect("BOM-less UTF-16LE MOBI text and EXTH metadata must decode");
    assert_eq!(book.title, "Книга 😀");
    assert_eq!(book.chapters[0].blocks[0].text, "Привет 😀");
}

#[test]
fn test_mobi_fixed_layout_hints_keep_text_on_explicit_reflow_fallback() {
    let text = b"<p>Accessible fallback text</p>";
    let book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![
            create_mobi_header_record(
                text.len() as u32,
                1,
                &[
                    (122, b"true".to_vec()),
                    (123, b"comic".to_vec()),
                    (124, b"landscape".to_vec()),
                    (125, 21u32.to_be_bytes().to_vec()),
                    (126, b"1072x1448".to_vec()),
                    (127, b"true".to_vec()),
                    (128, b"true".to_vec()),
                    (129, b"kindle:embed:0001".to_vec()),
                ],
            ),
            text.to_vec(),
        ]),
        None,
    )
    .expect("fixed-layout EXTH hints must not prevent text parsing");

    assert_eq!(book.chapters[0].blocks[0].text, "Accessible fallback text");
    let metadata = book.metadata.expect("MOBI metadata");
    assert_eq!(metadata["mobiLayoutPolicy"], "reflow_fallback");
    assert_eq!(metadata["mobiFixedLayout"], true);
    assert_eq!(metadata["mobiComicBookType"], true);
    assert_eq!(metadata["mobiOrientationLock"], "landscape");
    assert_eq!(metadata["mobiResourceCount"], 21);
    assert_eq!(metadata["mobiOriginalResolution"], "1072x1448");
    assert_eq!(metadata["mobiZeroGutter"], true);
    assert_eq!(metadata["mobiZeroMargin"], true);
    assert_eq!(metadata["mobiMetadataResourceUri"], "kindle:embed:0001");
}

#[test]
fn test_mobi_ignores_malformed_indx_and_tagx_records_outside_text_range() {
    let text = b"<h1>Chapter One</h1><p>Readable text</p>";
    let book = glibusta_core::book::mobi::parse_mobi(
        &create_palm_mobi(vec![
            create_mobi_header_record(text.len() as u32, 1, &[]),
            text.to_vec(),
            b"INDX\x00\x00\x00\x04\xFFmalformed index offsets".to_vec(),
            b"TAGX\x00\x00\x00\x0C\xFF\xFF\xFF\xFFinvalid control bytes".to_vec(),
        ]),
        None,
    )
    .expect("untrusted index records must not prevent the declared text stream from opening");
    let parsed_text = book
        .chapters
        .iter()
        .flat_map(|chapter| &chapter.blocks)
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert!(parsed_text.contains("Readable text"));
    assert!(!parsed_text.contains("INDX"));
    assert!(!parsed_text.contains("TAGX"));
    let metadata = book.metadata.expect("MOBI metadata");
    assert_eq!(metadata["mobiTocSource"], "chapter-splitter");
    assert_eq!(metadata["mobiIndxRecordCount"], 1);
    assert_eq!(metadata["mobiTagxRecordCount"], 1);
}

#[test]
fn test_mobi_index_probe_is_bounded_and_reports_truncation() {
    let text = b"<p>Readable text</p>";
    let mut records = vec![
        create_mobi_header_record(text.len() as u32, 1, &[]),
        text.to_vec(),
    ];
    records.extend(std::iter::repeat_n(b"INDX".to_vec(), 1025));

    let book = glibusta_core::book::mobi::parse_mobi(&create_palm_mobi(records), None)
        .expect("untrusted index records beyond the bounded probe must not prevent opening");

    let metadata = book.metadata.expect("MOBI metadata");
    assert_eq!(metadata["mobiIndxRecordCount"], 1024);
    assert_eq!(metadata["mobiTagxRecordCount"], 0);
    assert_eq!(metadata["mobiIndexProbeTruncated"], true);
    assert_eq!(metadata["mobiTocSource"], "chapter-splitter");
}

#[test]
fn test_mobi_dual_format_prefers_kf8_text_section() {
    let book = glibusta_core::book::mobi::parse_mobi(&create_dual_format_mobi(), None).unwrap();
    let text = book
        .chapters
        .iter()
        .flat_map(|chapter| &chapter.blocks)
        .map(|block| block.text.as_str())
        .collect::<Vec<_>>()
        .join("\n");

    assert!(text.contains("Modern KF8 text"));
    assert!(!text.contains("Legacy KF7 text"));
    assert_eq!(book.metadata.unwrap()["mobiKf8Likely"], true);
}

#[test]
fn test_mobi_invalid_kf8_boundary_falls_back_to_legacy_text() {
    let book =
        glibusta_core::book::mobi::parse_mobi(&create_mobi_with_invalid_kf8_boundary(), None)
            .unwrap();

    assert_eq!(book.chapters[0].blocks[0].text, "Readable legacy text");
}

#[test]
fn test_mobi_truncated_file_returns_an_error_without_panicking() {
    let result = glibusta_core::book::mobi::parse_mobi(&create_minimal_mobi()[..80], None);

    assert!(result.is_err());
}

#[test]
fn test_mobi_rejects_non_book_mobi_palm_database_container() {
    let mut mobi = create_minimal_mobi();
    mobi[60..64].copy_from_slice(b"DATA");

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("a non-BOOK Palm database must not be accepted as MOBI");

    assert!(error.to_string().contains("container"));

    mobi[60..64].copy_from_slice(b"BOOK");
    mobi[64..68].copy_from_slice(b"READ");
    assert!(glibusta_core::book::mobi::parse_mobi(&mobi, None).is_err());
}

#[test]
fn test_mobi_rejects_encrypted_palm_doc_before_text_decode() {
    let mut mobi = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([mobi[78], mobi[79], mobi[80], mobi[81]]) as usize;
    mobi[record0_offset + 12..record0_offset + 14].copy_from_slice(&1u16.to_be_bytes());

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("encrypted MOBI must not be decoded as plaintext");

    assert!(error.to_string().to_ascii_lowercase().contains("encrypted"));
}

#[test]
fn test_mobi_rejects_palm_doc_text_length_that_does_not_match_records() {
    for compression in [1u16, 2] {
        let mut mobi = create_minimal_mobi();
        let record0_offset = u32::from_be_bytes([mobi[78], mobi[79], mobi[80], mobi[81]]) as usize;
        // The single logical PalmDOC record contains the fixture's actual
        // text, but the header claims one additional byte.  Plain ASCII is a
        // valid literal stream for compression 2 as well as compression 1.
        let declared_length = u32::from_be_bytes([
            mobi[record0_offset + 4],
            mobi[record0_offset + 5],
            mobi[record0_offset + 6],
            mobi[record0_offset + 7],
        ]);
        mobi[record0_offset..record0_offset + 2].copy_from_slice(&compression.to_be_bytes());
        mobi[record0_offset + 4..record0_offset + 8]
            .copy_from_slice(&declared_length.saturating_add(1).to_be_bytes());

        let error = glibusta_core::book::mobi::parse_mobi(&mobi, None).expect_err(
            "PalmDOC text length must agree with decompressed records for every supported compression",
        );

        assert!(error.to_string().contains("text length"));
    }
}

#[test]
fn test_mobi_rejects_palm_doc_record_count_inconsistent_with_text_length() {
    let mobi = create_palm_mobi(vec![
        create_mobi_header_record(4097, 1, &[]),
        vec![b'x'; 4096],
    ]);

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("one record cannot contain a declared 4097-byte PalmDOC text stream");

    assert!(error.to_string().contains("record count"));
}

#[test]
fn test_mobi_rejects_nonstandard_palm_doc_logical_record_size() {
    let mut mobi = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([mobi[78], mobi[79], mobi[80], mobi[81]]) as usize;
    mobi[record0_offset + 10..record0_offset + 12].copy_from_slice(&2048u16.to_be_bytes());

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("PalmDOC logical records must be 4096 bytes");

    assert!(error.to_string().contains("logical record size"));
}

#[test]
fn test_mobi_honors_variable_header_length_before_reading_optional_fields() {
    let mut mobi = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([mobi[78], mobi[79], mobi[80], mobi[81]]) as usize;
    let mobi_offset = record0_offset + 16;

    // A 16-byte MOBI header contains text encoding, but not the optional Full
    // Name offsets. Values after that declared boundary must remain ignored.
    mobi[mobi_offset + 4..mobi_offset + 8].copy_from_slice(&16u32.to_be_bytes());
    mobi[mobi_offset + 84..mobi_offset + 88].copy_from_slice(&200u32.to_be_bytes());
    mobi[mobi_offset + 88..mobi_offset + 92].copy_from_slice(&14u32.to_be_bytes());
    mobi[record0_offset + 200..record0_offset + 214].copy_from_slice(b"Injected title");

    let book = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect("a valid short header must ignore trailing optional fields");

    assert_eq!(book.title, "Test MOBI");

    mobi[mobi_offset + 4..mobi_offset + 8].copy_from_slice(&249u32.to_be_bytes());
    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("declared MOBI header cannot extend past record 0");
    assert!(error.to_string().contains("header length exceeds record 0"));
}

#[test]
fn test_mobi_rejects_unsupported_huff_cdic_compression() {
    let mut mobi = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([mobi[78], mobi[79], mobi[80], mobi[81]]) as usize;
    mobi[record0_offset..record0_offset + 2].copy_from_slice(&17480u16.to_be_bytes());

    let error = glibusta_core::book::mobi::parse_mobi(&mobi, None)
        .expect_err("HUFF/CDIC MOBI must not be decoded with the PalmDOC codec");

    assert!(
        error
            .to_string()
            .contains("Unsupported MOBI compression: 17480")
    );
}

#[test]
#[cfg_attr(
    miri,
    ignore = "deterministic corruption corpus is covered by native tests"
)]
fn test_mobi_deterministic_corruption_corpus_never_panics() {
    let valid = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([valid[78], valid[79], valid[80], valid[81]]) as usize;
    let mut cases = Vec::new();
    cases.push(valid[..80].to_vec());

    let mut invalid_offset = valid.clone();
    invalid_offset[78..82].copy_from_slice(&u32::MAX.to_be_bytes());
    cases.push(invalid_offset);

    let mut unsorted_offsets = valid.clone();
    unsorted_offsets[86..90].copy_from_slice(&((record0_offset - 1) as u32).to_be_bytes());
    cases.push(unsorted_offsets);

    let mut unsupported_compression = valid.clone();
    unsupported_compression[record0_offset..record0_offset + 2]
        .copy_from_slice(&17480u16.to_be_bytes());
    cases.push(unsupported_compression);

    let mut invalid_record_count = valid.clone();
    invalid_record_count[record0_offset + 8..record0_offset + 10]
        .copy_from_slice(&2u16.to_be_bytes());
    cases.push(invalid_record_count);

    let mut invalid_header_length = valid.clone();
    invalid_header_length[record0_offset + 20..record0_offset + 24]
        .copy_from_slice(&u32::MAX.to_be_bytes());
    cases.push(invalid_header_length);

    let text = b"<p>EXTH length corpus</p>";
    let mut invalid_exth_length = create_palm_mobi(vec![
        create_mobi_header_record(text.len() as u32, 1, &[(503, b"Title".to_vec())]),
        text.to_vec(),
    ]);
    let exth_offset = invalid_exth_length
        .windows(4)
        .position(|window| window == b"EXTH")
        .expect("EXTH fixture marker");
    invalid_exth_length[exth_offset + 4..exth_offset + 8].copy_from_slice(&u32::MAX.to_be_bytes());
    cases.push(invalid_exth_length);

    for bytes in cases {
        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            glibusta_core::book::mobi::parse_mobi(&bytes, None)
        }));
        assert!(result.is_ok(), "corrupt MOBI input must not panic");
    }
}

#[test]
#[cfg_attr(
    miri,
    ignore = "deterministic byte mutation property is covered by native tests"
)]
fn test_mobi_single_byte_mutation_property_never_panics() {
    // A compact, deterministic stand-in for a fuzz seed: exercise every byte
    // of a valid PalmDB/MOBI container with values that commonly turn lengths,
    // offsets and compression flags into boundary values.  This stays fast
    // enough for the normal native suite while covering the parser's complete
    // input surface, rather than only hand-picked header fields.
    let valid = create_minimal_mobi();

    for index in 0..valid.len() {
        for replacement in [0, u8::MAX] {
            if valid[index] == replacement {
                continue;
            }
            let mut corrupted = valid.clone();
            corrupted[index] = replacement;

            let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                glibusta_core::book::mobi::parse_mobi(&corrupted, None)
            }));
            assert!(
                result.is_ok(),
                "MOBI parser panicked after mutating byte {index} to {replacement:#04x}",
            );
        }
    }
}

#[test]
#[cfg_attr(miri, ignore = "path cache uses external filesystem state")]
fn test_rejected_mobi_never_populates_path_cache() {
    let path = std::env::temp_dir().join(format!(
        "glibusta-invalid-mobi-{}_{}.mobi",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    let path_text = path.to_string_lossy().into_owned();
    let mut invalid_mobi = create_minimal_mobi();
    let record0_offset = u32::from_be_bytes([
        invalid_mobi[78],
        invalid_mobi[79],
        invalid_mobi[80],
        invalid_mobi[81],
    ]) as usize;
    invalid_mobi[record0_offset..record0_offset + 2].copy_from_slice(&17480u16.to_be_bytes());
    fs::write(&path, invalid_mobi).expect("write invalid MOBI fixture");

    assert!(glibusta_core::api::api::parse_book(path_text.clone()).is_err());
    assert!(
        glibusta_core::api::api::check_book_cache(path_text)
            .expect("check cache after rejected MOBI")
            .0,
        "a rejected MOBI must not be cached",
    );

    fs::remove_file(path).expect("remove invalid MOBI fixture");
}

#[test]
#[cfg_attr(miri, ignore = "path import uses external filesystem state")]
fn test_mobi_path_import_never_modifies_reader_sidecars() {
    let directory = std::env::temp_dir().join(format!(
        "glibusta-mobi-sidecars-{}_{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("system clock should be after Unix epoch")
            .as_nanos(),
    ));
    fs::create_dir(&directory).expect("create fixture directory");
    let mobi_path = directory.join("book.mobi");
    let mbp_path = directory.join("book.mbp");
    let lps_path = directory.join("book.lps");
    let sidecar = b"third-party reader bookmark data";
    fs::write(&mobi_path, create_minimal_mobi()).expect("write MOBI fixture");
    fs::write(&mbp_path, sidecar).expect("write existing MBP sidecar");

    let book = glibusta_core::api::api::parse_book(mobi_path.to_string_lossy().into_owned())
        .expect("parse MOBI without touching reader sidecars");

    assert_eq!(book.title, "Test MOBI");
    assert_eq!(fs::read(&mbp_path).expect("read MBP sidecar"), sidecar);
    assert!(
        !lps_path.exists(),
        "MOBI import must not create an LPS synchronization sidecar",
    );

    fs::remove_dir_all(directory).expect("remove fixture directory");
}

#[test]
fn test_mobi_preserves_safe_links_and_drops_unsafe_schemes() {
    let mobi_bytes = create_mobi_with_text(
        b"<html><body><p><a href=\"https://example.com\">Safe</a> <a href=\"javascript:alert(1)\">Unsafe</a></p></body></html>",
    );
    let book = glibusta_core::book::mobi::parse_mobi(&mobi_bytes, None).unwrap();
    let spans = book.chapters[0].blocks[0].rich_spans.as_ref().unwrap();

    assert_eq!(spans[0].href.as_deref(), Some("https://example.com"));
    assert!(
        spans
            .iter()
            .any(|span| span.text == "Unsafe" && span.href.is_none())
    );
}

#[test]
fn test_mobi_builds_toc_from_detected_chapters() {
    let mobi_bytes = create_mobi_with_text(
        b"<html><body><h1>Chapter One</h1><p>First.</p><h1>Chapter Two</h1><p>Second.</p></body></html>",
    );
    let book = glibusta_core::book::mobi::parse_mobi(&mobi_bytes, None).unwrap();

    assert_eq!(book.toc.len(), 2);
    assert_eq!(book.toc[0].title, "Chapter One");
    assert_eq!(book.toc[0].chapter_index, 0);
    assert_eq!(book.toc[1].title, "Chapter Two");
    assert_eq!(book.toc[1].chapter_index, 1);
}

#[test]
#[cfg_attr(miri, ignore)] // insta uses fork() which Miri doesn't support
fn test_mobi_golden_snapshot() {
    let mobi_bytes = create_minimal_mobi();
    let book = glibusta_core::book::mobi::parse_mobi(&mobi_bytes, None).unwrap();
    let snapshot = serde_json::json!({
        "format": format!("{:?}", book.book_format),
        "chapters": book.chapters.len(),
        "blocks": book.chapters.iter().map(|c| c.blocks.len()).sum::<usize>(),
        "language": book.language,
    });
    insta::assert_snapshot!("mobi_golden", snapshot.to_string());
}

// ---------------------------------------------------------------------------
// DjVu tests — parse from embedded binary
// ---------------------------------------------------------------------------

/// Minimal 4×4 DjVu with no text layer (49 bytes)
const MINIMAL_DJVU: &[u8] = &[
    0x41, 0x54, 0x26, 0x54, 0x46, 0x4f, 0x52, 0x4d, 0x00, 0x00, 0x00, 0x20, 0x44, 0x4a, 0x56, 0x55,
    0x49, 0x4e, 0x46, 0x4f, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x02, 0x00, 0x02, 0x18, 0x00, 0x2c, 0x01,
    0x16, 0x01, 0x53, 0x6a, 0x62, 0x7a, 0x00, 0x00, 0x00, 0x02, 0xab, 0x7f,
];

/// 4×4 DjVu with "Hello World" text layer (88 bytes)
const DJVU_WITH_TEXT: &[u8] = &[
    0x41, 0x54, 0x26, 0x54, 0x46, 0x4f, 0x52, 0x4d, 0x00, 0x00, 0x00, 0x4c, 0x44, 0x4a, 0x56, 0x55,
    0x49, 0x4e, 0x46, 0x4f, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x04, 0x00, 0x04, 0x18, 0x00, 0x2c, 0x01,
    0x16, 0x01, 0x53, 0x6a, 0x62, 0x7a, 0x00, 0x00, 0x00, 0x07, 0x9b, 0x69, 0xe7, 0xba, 0xed, 0x93,
    0x17, 0x00, 0x54, 0x58, 0x54, 0x7a, 0x00, 0x00, 0x00, 0x1e, 0xff, 0xff, 0xde, 0x88, 0xce, 0x6e,
    0xd5, 0x2c, 0x80, 0x35, 0xfb, 0x4e, 0x14, 0xf9, 0xd7, 0x47, 0x14, 0x6e, 0x25, 0xf0, 0xfb, 0x3a,
    0x67, 0xfa, 0x55, 0xde, 0xb2, 0x8e, 0xed, 0xbf,
];

#[test]
fn test_djvu_page_count() {
    assert_eq!(
        glibusta_core::book::djvu::DjvuEngine::page_count(MINIMAL_DJVU).unwrap(),
        1
    );
}

#[test]
fn test_djvu_extract_text_empty() {
    let text = glibusta_core::book::djvu::DjvuEngine::extract_text(MINIMAL_DJVU).unwrap();
    assert!(text.is_empty(), "DjVu without TXTz should produce no text");
}

#[test]
fn test_djvu_extract_text() {
    let text = glibusta_core::book::djvu::DjvuEngine::extract_text(DJVU_WITH_TEXT).unwrap();
    assert_eq!(text.trim(), "Hello World");
}

#[test]
fn test_djvu_corrupt_text_layer_returns_controlled_error() {
    let mut corrupt = DJVU_WITH_TEXT.to_vec();
    *corrupt
        .last_mut()
        .expect("DjVu text fixture must contain a TXTz payload") ^= 0xFF;

    let text_error = glibusta_core::book::djvu::DjvuEngine::extract_text(&corrupt)
        .expect_err("corrupt TXTz must not be silently treated as an empty text layer");
    assert!(text_error.to_string().contains("text layer"));

    let parse_error = glibusta_core::book::djvu::DjvuEngine::parse_djvu(&corrupt).expect_err(
        "book parser must surface corrupt TXTz instead of producing a placeholder page",
    );
    assert!(parse_error.to_string().contains("text layer"));
}

#[test]
#[cfg_attr(miri, ignore)] // zlib-rs flate2 dealloc UB in dependency
fn test_djvu_render_page() {
    let png =
        glibusta_core::book::djvu::DjvuEngine::render_page_to_png(MINIMAL_DJVU, 0, 100).unwrap();
    assert!(!png.is_empty(), "PNG output should not be empty");
    assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n", "should be valid PNG");
}

#[test]
fn test_djvu_parse_book() {
    let book = glibusta_core::book::djvu::DjvuEngine::parse_djvu(MINIMAL_DJVU).unwrap();
    assert_eq!(book.chapters.len(), 1, "should have 1 chapter");
    assert_eq!(book.book_format, BookFormat::Djvu);
}

#[test]
fn test_djvu_parse_book_with_text() {
    let book = glibusta_core::book::djvu::DjvuEngine::parse_djvu(DJVU_WITH_TEXT).unwrap();
    assert_eq!(book.chapters.len(), 1);
    if let Some(block) = book.chapters[0].blocks.first() {
        assert!(block.text.contains("Hello"), "text should contain 'Hello'");
    } else {
        panic!("expected at least one block");
    }
}

#[test]
fn test_taffy_layout() {
    let rects =
        glibusta_core::book::layout::compute_vertical_layout(400.0, &[100.0, 50.0, 200.0], 10.0)
            .unwrap();
    assert_eq!(rects.len(), 3);
    // Blocks should stack vertically
    assert!(
        rects[1].y > rects[0].y,
        "second block should be below first"
    );
    assert!(
        rects[2].y > rects[1].y,
        "third block should be below second"
    );
    assert!((rects[0].y - 0.0).abs() < f32::EPSILON);
    assert!((rects[1].y - 110.0).abs() < f32::EPSILON);
    assert!((rects[2].y - 170.0).abs() < f32::EPSILON);
    // Widths should match container
    for r in &rects {
        assert!((r.width - 400.0).abs() < 1.0, "width should be ~400");
    }
}
