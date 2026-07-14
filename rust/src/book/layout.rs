//! LW-1.3: CSS Flexbox layout engine prototype using taffy.
//! Computes block positions and dimensions using CSS Flexbox algorithm.

use serde::{Deserialize, Serialize};
use taffy::prelude::*;
use taffy::tree::TaffyTree;

/// Layout result for a single block.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutRect {
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

/// Compute flexbox layout for a vertical stack of blocks.
/// Returns bounding boxes for each block.
pub fn compute_vertical_layout(
    container_width: f32,
    block_heights: &[f32],
    gaps: f32,
) -> anyhow::Result<Vec<LayoutRect>> {
    let mut tree: TaffyTree = TaffyTree::new();

    let mut children = Vec::new();
    for &h in block_heights {
        let node = tree.new_leaf(Style {
            size: Size {
                width: length(container_width),
                height: length(h),
            },
            margin: Rect {
                top: length(0.0_f32),
                bottom: length(gaps),
                left: length(0.0_f32),
                right: length(0.0_f32),
            },
            ..Default::default()
        })?;
        children.push(node);
    }

    let root = tree.new_with_children(
        Style {
            display: Display::Flex,
            flex_direction: FlexDirection::Column,
            size: Size {
                width: length(container_width),
                height: auto(),
            },
            ..Default::default()
        },
        &children,
    )?;

    tree.compute_layout(
        root,
        Size {
            width: AvailableSpace::Definite(container_width),
            height: AvailableSpace::MaxContent,
        },
    )?;

    children
        .iter()
        .map(|&node| {
            let layout = tree.layout(node)?;
            Ok(LayoutRect {
                x: layout.location.x,
                y: layout.location.y,
                width: layout.size.width,
                height: layout.size.height,
            })
        })
        .collect()
}
