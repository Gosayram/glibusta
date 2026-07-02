use std::io::Write;

use glibusta_core::{
    BlockType, BookFormat, NormalizedBook, ReaderBlock, ReaderChapter, TocEntry,
};

/// ---------------------------------------------------------------------------
/// FB2 tests — parse from XML string
/// ---------------------------------------------------------------------------

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
    assert_eq!(book.chapters[0].blocks.len(), 2);
    assert_eq!(book.chapters[1].blocks.len(), 1);
}

#[test]
fn test_fb2_with_cover() {
    let book = glibusta_core::book::fb2::parse_fb2(FB2_WITH_COVER.as_bytes(), None).unwrap();
    assert!(
        book.cover_url.is_some(),
        "cover_url should be present"
    );
    assert!(
        book.cover_url.unwrap().starts_with("data:image/jpeg;base64,")
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

/// ---------------------------------------------------------------------------
/// TXT tests — encoding detection + chapter splitting
/// ---------------------------------------------------------------------------

#[test]
fn test_txt_utf8_plain() {
    let text = "\u{41}\u{43}\u{43}\u{6f}\u{75}\u{6e}\u{74}\n\n\u{41} \u{62}\u{6f}\u{6f}\u{6b}\u{2e}\n".to_string();
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

/// ---------------------------------------------------------------------------
/// EPUB tests — minimal in-memory EPUB
/// ---------------------------------------------------------------------------

fn create_minimal_epub() -> Vec<u8> {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);

    let options = zip::write::FileOptions::<()>::default()
        .compression_method(zip::CompressionMethod::Stored);

    zip.start_file("META-INF/container.xml", options).unwrap();
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
    zip.write_all(
        br#"<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata>
    <dc:title>Test EPUB</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
    <dc:description>A test EPUB book.</dc:description>
  </metadata>
  <manifest>
    <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chapter1"/>
  </spine>
</package>"#,
    )
    .unwrap();

    zip.start_file("chapter1.xhtml", options).unwrap();
    zip.write_all(
        br#"<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>Chapter 1</title></head>
  <body>
    <p>First paragraph.</p>
    <p>Second paragraph.</p>
  </body>
</html>"#,
    )
    .unwrap();

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

/// ---------------------------------------------------------------------------
/// DOCX tests — minimal in-memory DOCX
/// ---------------------------------------------------------------------------

fn create_minimal_docx() -> Vec<u8> {
    let mut buf = std::io::Cursor::new(Vec::new());
    let mut zip = zip::ZipWriter::new(&mut buf);

    let options = zip::write::FileOptions::<()>::default()
        .compression_method(zip::CompressionMethod::Stored);

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
    assert_eq!(blocks[0].block_type, BlockType::Heading);
}

/// ---------------------------------------------------------------------------
/// RTF tests
/// ---------------------------------------------------------------------------

#[test]
fn test_rtf_basic_parse() {
    let rtf_text = br"{\rtf1\ansi\deff0
{\fonttbl {\f0 Times New Roman;}}
\f0\fs24 Hello, world!\par
This is a second paragraph.\par
}";
    let book = glibusta_core::book::rtf::parse_rtf(rtf_text, None).unwrap();
    assert!(!book.chapters.is_empty(), "should have chapters");
    let blocks = &book.chapters[0].blocks;
    assert!(!blocks.is_empty(), "should have blocks");
    assert_eq!(blocks[0].text, "Hello, world!");
    assert_eq!(book.book_format, BookFormat::Rtf);
}

/// ---------------------------------------------------------------------------
/// Edge case tests
/// ---------------------------------------------------------------------------

#[test]
fn test_book_format_from_ext() {
    assert_eq!(BookFormat::from_ext("fb2"), BookFormat::Fb2);
    assert_eq!(BookFormat::from_ext("ePuB"), BookFormat::Epub);
    assert_eq!(BookFormat::from_ext("TXT"), BookFormat::Txt);
    assert_eq!(BookFormat::from_ext("docx"), BookFormat::Docx);
    assert_eq!(BookFormat::from_ext("mobi"), BookFormat::Mobi);
    assert_eq!(BookFormat::from_ext("pdf"), BookFormat::Pdf);
    assert_eq!(BookFormat::from_ext("djvu"), BookFormat::Djvu);
    assert_eq!(
        BookFormat::from_ext("unknown"),
        BookFormat::Unknown
    );
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
