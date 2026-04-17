"""Abstract base class and shared data models for book export.

Provides NodeInfo, TocEntry dataclasses and the BookExporter ABC used by
PdfBookExporter and DocxBookExporter.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class NodeInfo:
    """Represents a single outline node with its lecture content.

    Attributes
    ----------
    node_id:
        Unique identifier for the node.
    text:
        The node's display title (used as chapter heading).
    depth:
        Depth in the outline tree (1–4).
    blocks:
        Ordered list of LectureBlock dicts (JSONB from DB).
        An empty list means the node has no lecture content.
    """

    node_id: str
    text: str
    depth: int
    blocks: list[dict] = field(default_factory=list)


@dataclass
class TocEntry:
    """A single entry in the Table of Contents.

    Attributes
    ----------
    title:
        Chapter/section title shown in the TOC.
    depth:
        Outline depth (1–4); controls indentation.
    page:
        Page number (PDF only; set to 0 for Word exports).
    anchor:
        Bookmark name used for hyperlinks in Word exports,
        e.g. ``"node_L1_材料力学"``.
    """

    title: str
    depth: int
    page: int
    anchor: str


class BookExporter(ABC):
    """Abstract base class for book exporters.

    Subclasses implement :meth:`build` to produce a binary file (PDF or
    Word) from an ordered list of :class:`NodeInfo` objects.
    """

    # ------------------------------------------------------------------
    # Shared helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _filter_nodes(nodes: list[NodeInfo]) -> list[NodeInfo]:
        """Return only nodes that have non-empty ``blocks``.

        Nodes with an empty ``blocks`` list are silently skipped per
        Requirement 2.3.

        Parameters
        ----------
        nodes:
            Input list in outline order.

        Returns
        -------
        list[NodeInfo]
            Filtered list preserving original order.
        """
        return [n for n in nodes if n.blocks]

    # ------------------------------------------------------------------
    # Abstract interface
    # ------------------------------------------------------------------

    @abstractmethod
    def build(
        self,
        session_title: str,
        nodes: list[NodeInfo],
        include_toc: bool = True,
    ) -> bytes:
        """Generate the export document and return its raw bytes.

        Parameters
        ----------
        session_title:
            Title of the conversation session; used as the document title.
        nodes:
            Ordered list of nodes to include.  Nodes with empty ``blocks``
            will be filtered out internally via :meth:`_filter_nodes`.
        include_toc:
            When ``True`` a Table of Contents is prepended to the document.

        Returns
        -------
        bytes
            The complete file content (PDF or DOCX binary).
        """
