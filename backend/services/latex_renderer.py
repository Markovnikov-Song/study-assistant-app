"""LaTeX renderer using matplotlib mathtext — no full LaTeX installation required."""

from __future__ import annotations

import io


class LatexRenderer:
    """Render LaTeX strings to PNG bytes using matplotlib mathtext.

    Results are cached per instance so identical formulas within the same
    export request are only rendered once (Requirement 6.4).
    """

    def __init__(self) -> None:
        self._cache: dict[str, bytes] = {}

    def render(self, latex: str, display: bool = False) -> bytes | None:
        """Render *latex* to a PNG and return the raw bytes.

        Parameters
        ----------
        latex:
            The LaTeX source string (without surrounding ``$`` delimiters).
        display:
            When *True* the formula is rendered in display (block) style at a
            larger font size; when *False* it is rendered inline.

        Returns
        -------
        bytes | None
            PNG bytes on success, ``None`` on any rendering failure.
        """
        cache_key = f"{'display' if display else 'inline'}:{latex}"
        if cache_key in self._cache:
            return self._cache[cache_key]

        try:
            import matplotlib
            matplotlib.use("Agg")  # non-interactive backend, safe for threads
            import matplotlib.pyplot as plt

            fontsize = 14 if display else 11
            fig = plt.figure(figsize=(0.01, 0.01))
            fig.text(0, 0, f"${latex}$", fontsize=fontsize)

            buf = io.BytesIO()
            fig.savefig(buf, format="png", bbox_inches="tight", pad_inches=0.1, dpi=150)
            plt.close(fig)

            buf.seek(0)
            result = buf.read()
            self._cache[cache_key] = result
            return result
        except Exception:
            return None
