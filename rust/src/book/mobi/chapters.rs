use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;

use crate::api::models::{BlockType, ReaderBlock, ReaderChapter};

use super::TAG_RE;

static CHAPTER_PATTERN_RE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)(?:^|\n)\s*(?:(?:глава|часть|раздел|пролог|эпилог|предисловие|послесловие)\s*\d*|(?:chapter|part|section|prologue|epilogue|preface|afterword)\s*\d*)\s*(?:\n|$)",
    )
    .unwrap()
});

struct ChapterChunk {
    title: String,
    blocks: Vec<ReaderBlock>,
}

pub(crate) struct MobiChapterSplitter;

impl MobiChapterSplitter {
    pub fn new() -> Self {
        Self
    }

    pub fn split(&self, blocks: &[ReaderBlock]) -> Vec<ReaderChapter> {
        if blocks.is_empty() {
            return vec![ReaderChapter {
                index: 0,
                title: "Документ".to_string(),
                blocks: vec![ReaderBlock {
                    index: 0,
                    text: "Не удалось извлечь текст.".to_string(),
                    block_type: BlockType::Paragraph,
                    image_url: None,
                    note_ref: None,
                    rich_spans: None,
                }],
            }];
        }

        let chunks = self.split_blocks_into_chunks(blocks);
        if chunks.len() <= 1 {
            let title = if !chunks.is_empty() {
                chunks[0].title.clone()
            } else {
                "Документ".to_string()
            };
            return vec![ReaderChapter {
                index: 0,
                title,
                blocks: blocks.to_vec(),
            }];
        }

        chunks
            .into_iter()
            .enumerate()
            .map(|(i, chunk)| ReaderChapter {
                index: i as i32,
                title: chunk.title,
                blocks: chunk.blocks,
            })
            .collect()
    }

    fn split_blocks_into_chunks(&self, blocks: &[ReaderBlock]) -> Vec<ChapterChunk> {
        let mut breaks: Vec<usize> = Vec::new();
        let mut titles: HashMap<usize, String> = HashMap::new();

        for (i, block) in blocks.iter().enumerate() {
            match block.block_type {
                BlockType::Heading => {
                    breaks.push(i);
                    titles.insert(i, block.text.clone());
                }
                BlockType::Separator if i > 0 && i < blocks.len() - 1 => {
                    if !self.is_nearby_heading(blocks, i) {
                        breaks.push(i);
                    }
                }
                BlockType::Paragraph => {
                    let text = &block.text;
                    let test = format!("\n{}\n", text);
                    if CHAPTER_PATTERN_RE.is_match(&test) {
                        breaks.push(i);
                        titles.insert(i, text.clone());
                    }
                }
                _ => {}
            }
        }

        if breaks.is_empty() {
            return self.chunk_by_size(blocks);
        }

        if breaks[0] != 0 {
            breaks.insert(0, 0);
            titles.insert(0, "Документ".to_string());
        }

        if breaks.len() == 1 {
            let title = titles
                .get(&breaks[0])
                .cloned()
                .unwrap_or_else(|| "Документ".to_string());
            return vec![ChapterChunk {
                title: self.clean_title(&title),
                blocks: blocks.to_vec(),
            }];
        }

        let chunk_map: HashSet<usize> = breaks.iter().copied().collect();
        let mut chunks: Vec<ChapterChunk> = Vec::new();

        for (b, &brk) in breaks.iter().enumerate() {
            let start = brk;
            let end = if b + 1 < breaks.len() {
                breaks[b + 1]
            } else {
                blocks.len()
            };
            let chapter_blocks: Vec<ReaderBlock> = blocks[start..end]
                .iter()
                .filter(|bl| {
                    !(bl.block_type == BlockType::Separator
                        && chunk_map.contains(&(bl.index as usize)))
                })
                .cloned()
                .collect();
            if chapter_blocks.is_empty() {
                continue;
            }
            let title = titles
                .get(&brk)
                .cloned()
                .unwrap_or_else(|| format!("Часть {}", chunks.len() + 1));
            chunks.push(ChapterChunk {
                title: self.clean_title(&title),
                blocks: chapter_blocks,
            });
        }

        chunks
    }

    fn is_nearby_heading(&self, blocks: &[ReaderBlock], index: usize) -> bool {
        let start = index.saturating_sub(2);
        let end = std::cmp::min(index + 2, blocks.len() - 1);
        for block in blocks.iter().take(end + 1).skip(start) {
            if block.block_type == BlockType::Heading {
                return true;
            }
        }
        false
    }

    fn chunk_by_size(&self, blocks: &[ReaderBlock]) -> Vec<ChapterChunk> {
        const CHUNK_SIZE: usize = 80;
        let mut chunks: Vec<ChapterChunk> = Vec::new();
        let mut start = 0;
        while start < blocks.len() {
            let end = std::cmp::min(start + CHUNK_SIZE, blocks.len());
            chunks.push(ChapterChunk {
                title: format!("Часть {}", chunks.len() + 1),
                blocks: blocks[start..end].to_vec(),
            });
            start = end;
        }
        chunks
    }

    fn clean_title(&self, raw: &str) -> String {
        let stripped = TAG_RE.replace_all(raw, "");
        let mut title = stripped.trim().to_string();
        if title.len() > 80 {
            title.truncate(80);
            title.push('…');
        }
        if title.is_empty() {
            "Без названия".to_string()
        } else {
            title
        }
    }
}
