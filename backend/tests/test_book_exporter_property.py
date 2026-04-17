"""Property-based tests for BookExporter.

# Feature: lecture-book-export, Property 2: 无讲义节点静默跳�?
"""
from __future__ import annotations

import sys
import os

# Ensure backend package is importable when running from repo root
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from book_services.book_exporter import BookExporter, NodeInfo


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

_node_text = st.text(
    alphabet=st.characters(
        whitelist_categories=("Lu", "Ll", "Nd", "Lo"),
        whitelist_characters=" _-",
    ),
    min_size=1,
    max_size=30,
)

_block = st.fixed_dictionaries({
    "type": st.sampled_from(["paragraph", "heading", "code", "list", "quote"]),
    "text": st.text(min_size=1, max_size=50),
})


@st.composite
def node_list_with_some_empty(draw):
    """Generate a list of NodeInfo where a random subset has empty blocks.

    Returns
    -------
    tuple[list[NodeInfo], set[str]]
        (nodes, empty_node_ids) �?the full list and the IDs of empty nodes.
    """
    n = draw(st.integers(min_value=1, max_value=20))
    nodes = []
    empty_ids: set[str] = set()

    for i in range(n):
        node_id = f"node_{i}"
        text = draw(_node_text)
        depth = draw(st.integers(min_value=1, max_value=4))
        is_empty = draw(st.booleans())

        if is_empty:
            blocks: list[dict] = []
            empty_ids.add(node_id)
        else:
            blocks = draw(st.lists(_block, min_size=1, max_size=5))

        nodes.append(NodeInfo(node_id=node_id, text=text, depth=depth, blocks=blocks))

    return nodes, empty_ids


# ---------------------------------------------------------------------------
# Property 2: 无讲义节点静默跳�?
# Validates: Requirements 2.3
# ---------------------------------------------------------------------------

@given(node_list_with_some_empty())
@settings(max_examples=100, deadline=None)
def test_filter_nodes_silent_skip(node_data):
    """Property 2: 无讲义节点静默跳�?

    For any list of NodeInfo objects where a random subset has empty blocks,
    _filter_nodes() must:
    1. Return exactly as many nodes as there are nodes with non-empty blocks.
    2. Not include any node whose blocks list was empty.

    Validates: Requirements 2.3
    # Feature: lecture-book-export, Property 2: 无讲义节点静默跳�?
    """
    nodes, empty_ids = node_data

    expected_count = sum(1 for n in nodes if n.blocks)
    result = BookExporter._filter_nodes(nodes)

    # Assert count matches nodes-with-blocks count
    assert len(result) == expected_count, (
        f"Expected {expected_count} nodes after filtering, got {len(result)}. "
        f"Total nodes: {len(nodes)}, empty nodes: {len(empty_ids)}"
    )

    # Assert no empty-block node titles appear in the filtered result
    result_ids = {n.node_id for n in result}
    leaked = empty_ids & result_ids
    assert not leaked, (
        f"Empty-block nodes leaked into filtered result: {leaked}"
    )
