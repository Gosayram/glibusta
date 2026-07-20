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
        br##"<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><body><section><image l:href="images/page.webp"/></section></body></FictionBook>"##,
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
fn test_epub_toc_ncx() {
    let epub_bytes = create_minimal_epub();
    let book = glibusta_core::book::epub::parse_epub(&epub_bytes, None).unwrap();
    assert!(!book.toc.is_empty(), "TOC should have entries");
    assert_eq!(book.toc[0].title, "Chapter 1");
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

    assert_eq!(text, "Visibletext.");
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
    assert!(result.is_ok(), "Should handle malformed FB2 gracefully");
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

#[test]
fn test_mobi_basic_parse() {
    let mobi_bytes = create_minimal_mobi();
    let book = glibusta_core::book::mobi::parse_mobi(&mobi_bytes, None).unwrap();
    assert!(!book.chapters.is_empty(), "should have chapters");
    assert!(!book.chapters[0].blocks.is_empty(), "should have blocks");
    assert_eq!(book.book_format, BookFormat::Mobi);
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
