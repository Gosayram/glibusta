//! CRT-20.2/20.3: PDF rendering and text extraction via PDFium.
//! Gated behind the `pdf` feature flag.

use anyhow::Result;
use pdfium_render::prelude::*;
use std::sync::{Mutex, MutexGuard, OnceLock};

static PDFIUM: OnceLock<Mutex<Pdfium>> = OnceLock::new();

fn pdfium() -> Result<MutexGuard<'static, Pdfium>> {
    let mutex = PDFIUM
        .get_or_try_init(|| Pdfium::bind_to_system_library().map(Pdfium::new).map(Mutex::new))
        .map_err(|e| anyhow::anyhow!("PDFium init failed: {e}"))?;
    Ok(mutex.lock().unwrap())
}

pub struct PdfEngine;

impl PdfEngine {
    pub fn new() -> Result<Self> {
        pdfium()?;
        Ok(Self)
    }

    pub fn render_page_to_png(
        &self,
        bytes: &[u8],
        page_index: usize,
        max_width: u16,
    ) -> Result<Vec<u8>> {
        let pdfium = pdfium()?;
        let document = pdfium.load_pdf_from_byte_slice(bytes, None)?;
        let page = document.pages().get(page_index as i32)?;
        let viewport_width = (max_width as i32).min(1080);
        let render_cfg = PdfRenderConfig::new()
            .set_target_width(viewport_width)
            .set_maximum_width(viewport_width);
        let bitmap = page.render_with_config(&render_cfg)?;
        let img = bitmap.as_image()?;
        let mut png_bytes = Vec::new();
        let mut cursor = std::io::Cursor::new(&mut png_bytes);
        img.write_to(&mut cursor, image::ImageFormat::Png)?;
        Ok(png_bytes)
    }

    pub fn extract_text(&self, bytes: &[u8]) -> Result<String> {
        let pdfium = pdfium()?;
        let document = pdfium.load_pdf_from_byte_slice(bytes, None)?;
        let mut text = String::new();
        for i in 0..document.pages().len() {
            let page = document.pages().get(i)?;
            let page_text = page.text()?;
            text.push_str(&page_text.all());
            text.push('\n');
        }
        Ok(text)
    }

    pub fn page_count(&self, bytes: &[u8]) -> Result<i32> {
        let pdfium = pdfium()?;
        let document = pdfium.load_pdf_from_byte_slice(bytes, None)?;
        Ok(document.pages().len())
    }
}
