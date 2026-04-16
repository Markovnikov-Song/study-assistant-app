"""Property-based tests for export-book route validation.

# Feature: lecture-book-export, Property 6: 非法请求体被拒绝且不触发生成
# Feature: lecture-book-export, Property 7: Session 所有权校验
"""
from __future__ import annotations

import sys
import os
from types import ModuleType
from unittest.mock import MagicMock

# Ensure backend package is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# ---------------------------------------------------------------------------
# Stub out modules that require a live DB / environment before importing
# the router under test.
# ---------------------------------------------------------------------------

def _make_stub(name: str) -> ModuleType:
    mod = ModuleType(name)
    sys.modules[name] = mod
    return mod


for _mod_name in ("database", "deps"):
    if _mod_name not in sys.modules:
        _stub = _make_stub(_mod_name)
        # Provide the symbols that routers/library.py imports from these modules
        if _mod_name == "database":
            for _sym in (
                "ConversationHistory",
                "ConversationSession",
                "MindmapNodeState",
                "NodeLecture",
                "Subject",
            ):
                setattr(_stub, _sym, MagicMock())
            _stub.get_session = MagicMock()
        elif _mod_name == "deps":
            _stub.get_current_user = MagicMock()

from unittest.mock import patch
import pytest
from fastapi import HTTPException
from hypothesis import given, settings
from hypothesis import strategies as st
from pydantic import ValidationError

from routers.library import ExportBookIn, _assert_session_owner


# ---------------------------------------------------------------------------
# Strategies
# ---------------------------------------------------------------------------

_invalid_format = st.text(min_size=1, max_size=20).filter(
    lambda s: s not in ("pdf", "docx")
)

_valid_node_ids = st.lists(
    st.text(min_size=1, max_size=30),
    min_size=1,
    max_size=10,
)

_random_user_id = st.integers(min_value=1, max_value=10_000)
_random_session_id = st.integers(min_value=1, max_value=10_000)


# ---------------------------------------------------------------------------
# Property 6: 非法请求体被拒绝且不触发生成
# Validates: Requirements 7.3, 7.4
# ---------------------------------------------------------------------------

@given(fmt=st.sampled_from(["pdf", "docx"]))
@settings(max_examples=50, deadline=None)
def test_empty_node_ids_raises_validation_error(fmt):
    """Property 6 (empty node_ids): 非法请求体被拒绝且不触发生成

    For any request with an empty node_ids array, ExportBookIn validation
    must raise ValidationError.  Because Pydantic raises before the route
    body executes, BookExporter.build() can never be called.

    Validates: Requirements 7.3
    # Feature: lecture-book-export, Property 6: 非法请求体被拒绝且不触发生成
    """
    build_called = False

    # Patch the local import inside the route function body to detect any call
    mock_exporter = MagicMock()
    mock_exporter.build.side_effect = lambda **kw: (_ for _ in ()).throw(
        AssertionError("build() must not be called when validation fails")
    )

    with patch("routers.library.PdfBookExporter", return_value=mock_exporter, create=True), \
         patch("routers.library.DocxBookExporter", return_value=mock_exporter, create=True):

        with pytest.raises(ValidationError):
            ExportBookIn(node_ids=[], format=fmt)

        # Validation raised before any exporter could be instantiated
        assert not mock_exporter.build.called, "build() must not be called on invalid input"


@given(node_ids=_valid_node_ids, fmt=_invalid_format)
@settings(max_examples=50, deadline=None)
def test_invalid_format_raises_validation_error(node_ids, fmt):
    """Property 6 (invalid format): 非法请求体被拒绝且不触发生成

    For any request with a format value other than 'pdf' or 'docx',
    ExportBookIn validation must raise ValidationError.  Because Pydantic
    raises before the route body executes, BookExporter.build() can never
    be called.

    Validates: Requirements 7.4
    # Feature: lecture-book-export, Property 6: 非法请求体被拒绝且不触发生成
    """
    mock_exporter = MagicMock()

    with patch("routers.library.PdfBookExporter", return_value=mock_exporter, create=True), \
         patch("routers.library.DocxBookExporter", return_value=mock_exporter, create=True):

        with pytest.raises(ValidationError):
            ExportBookIn(node_ids=node_ids, format=fmt)

        assert not mock_exporter.build.called, "build() must not be called on invalid input"


# ---------------------------------------------------------------------------
# Property 7: Session 所有权校验
# Validates: Requirements 7.5
# ---------------------------------------------------------------------------

@given(
    requesting_user_id=_random_user_id,
    session_id=_random_session_id,
)
@settings(max_examples=50, deadline=None)
def test_session_ownership_raises_404_for_wrong_user(
    requesting_user_id, session_id
):
    """Property 7: Session 所有权校验

    For any session_id that does not belong to the requesting user,
    _assert_session_owner must raise HTTPException(404) and no lecture
    data is queried.

    Validates: Requirements 7.5
    # Feature: lecture-book-export, Property 7: Session 所有权校验
    """
    mock_db = MagicMock()
    mock_query = mock_db.query.return_value
    mock_query.filter_by.return_value.first.return_value = None

    with pytest.raises(HTTPException) as exc_info:
        _assert_session_owner(mock_db, session_id, requesting_user_id)

    assert exc_info.value.status_code == 404

    # Ownership check was made with the correct identifiers
    mock_db.query.assert_called_once()
    mock_query.filter_by.assert_called_once_with(
        id=session_id, user_id=requesting_user_id
    )

    # No further DB queries (no lecture data fetched)
    assert mock_db.query.call_count == 1
