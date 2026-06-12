#!/usr/bin/env python3
"""Inject embedded fonts into the OPF manifest of a tex4ebook-generated EPUB.

Scans an unpacked EPUB directory for font files (OTF, TTF, WOFF, WOFF2)
under ``OEBPS/fonts/``, adds corresponding ``<item>`` entries to the
``<manifest>`` of ``content.opf``, and re-packages the directory as a valid
EPUB.

This script is designed to be invoked by the project's ``Makefile`` after
``tex4ebook`` produces the initial EPUB.

Examples
--------
Inject fonts into an unpacked EPUB directory and write the result::

    $ python3 scripts/fix_epub_fonts.py epub_work salida/catedraciencias.epub

Let the script derive the output path from the input directory name::

    $ python3 scripts/fix_epub_fonts.py epub_work

Notes
-----
* The ``mimetype`` entry is stored first and uncompressed (per the EPUB
  specification).
* Font entries are flagged with ``properties="remote-resources"`` so EPUB
  reading systems can resolve them even when the OPF is served remotely.
"""

import argparse
import shutil
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import ClassVar

# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------


@dataclass
class FontFile:
    """Metadata for a single font file to be injected into the EPUB manifest.

    Attributes
    ----------
    font_path : Path
        Absolute or relative path to the font file on disk.
    media_type : str
        MIME type string (e.g. ``"font/otf"``).  Inferred automatically from
        the file extension.
    manifest_id : str
        Unique identifier used for the ``id`` attribute in the OPF ``<item>``.

    Notes
    -----
    Only OTF, TTF, WOFF, and WOFF2 extensions are recognised; any other
    extension receives ``application/octet-stream``.
    """

    MEDIA_TYPE_MAP: ClassVar[dict[str, str]] = {
        ".otf": "font/otf",
        ".ttf": "font/ttf",
        ".woff": "font/woff",
        ".woff2": "font/woff2",
    }
    """Mapping from lowercase file extension to MIME type string."""

    font_path: Path
    media_type: str = field(init=False)
    manifest_id: str = ""

    def __post_init__(self) -> None:
        ext: str = self.font_path.suffix.lower()
        fallback: str = "application/octet-stream"
        self.media_type = FontFile.MEDIA_TYPE_MAP.get(ext, fallback)

    # ------------------------------------------------------------------
    # Factory / discovery
    # ------------------------------------------------------------------

    @classmethod
    def discover(cls, fonts_dir: Path, id_prefix: str = "font") -> "list[FontFile]":
        """Scan *fonts_dir* and return a :class:`FontFile` for every recognised font.

        Parameters
        ----------
        fonts_dir : Path
            Directory to scan.  Only immediate children are checked.
        id_prefix : str
            Prefix for auto-generated manifest IDs (e.g. ``"font"`` →
            ``"font-1"``, ``"font-2"``, …).

        Returns
        -------
        list[FontFile]
            Sorted list (by filename) of discovered font files.

        Raises
        ------
        FileNotFoundError
            If *fonts_dir* does not exist.
        """
        if not fonts_dir.is_dir():
            raise FileNotFoundError(f"Fonts directory not found: {fonts_dir}")

        recognised: tuple[str, ...] = tuple(cls.MEDIA_TYPE_MAP.keys())
        files: list[Path] = sorted(
            p for p in fonts_dir.iterdir() if p.suffix.lower() in recognised
        )

        fonts: list[FontFile] = []
        for idx, path in enumerate(files, start=1):
            font = cls(font_path=path)
            font.manifest_id = f"{id_prefix}-{idx}"
            fonts.append(font)

        return fonts

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def href(self) -> str:
        """Relative path suitable for the ``href`` attribute of the OPF ``<item>``.

        Returns
        -------
        str
            Path relative to the OEBPS directory, e.g. ``"fonts/FiraCode.otf"``.
        """
        return f"fonts/{self.font_path.name}"


# ---------------------------------------------------------------------------
# Domain logic
# ---------------------------------------------------------------------------


class OpfManifest:
    """Read, modify, and write the ``<manifest>`` section of an OPF file.

    Parameters
    ----------
    tree : ET.ElementTree
        Parsed OPF document.
    """

    #: XML namespace map used for XPath queries inside the OPF.
    NS: ClassVar[dict[str, str]] = {"opf": "http://www.idpf.org/2007/opf"}

    def __init__(self, tree: ET.ElementTree) -> None:
        self._tree: ET.ElementTree = tree
        self._root: ET.Element = tree.getroot()
        manifest_el: ET.Element | None = self._root.find(".//opf:manifest", self.NS)
        if manifest_el is None:
            raise ValueError("No <manifest> element found in OPF")
        self._manifest: ET.Element = manifest_el
        self._existing_ids: set[str] = {
            item.get("id", "") for item in self._manifest.findall("opf:item", self.NS)
        }

    # ------------------------------------------------------------------
    # Factory
    # ------------------------------------------------------------------

    @classmethod
    def load(cls, opf_path: Path) -> "OpfManifest":
        """Parse an OPF file and return an :class:`OpfManifest`.

        Parameters
        ----------
        opf_path : Path
            Path to ``content.opf``.

        Returns
        -------
        OpfManifest

        Raises
        ------
        FileNotFoundError
            If *opf_path* does not exist.
        ValueError
            If the OPF contains no ``<manifest>`` element.
        """
        if not opf_path.is_file():
            raise FileNotFoundError(f"OPF file not found: {opf_path}")

        ET.register_namespace("", "http://www.idpf.org/2007/opf")
        ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

        tree: ET.ElementTree = ET.parse(opf_path)
        return cls(tree)

    # ------------------------------------------------------------------
    # Mutation
    # ------------------------------------------------------------------

    def add_font_entries(self, fonts: list[FontFile]) -> int:
        """Insert an ``<item>`` element into the manifest for each font.

        Automatically resolves manifest ID conflicts by appending a counter
        suffix if a generated ID already exists.

        Parameters
        ----------
        fonts : list[FontFile]
            Font entries to add.

        Returns
        -------
        int
            Number of font entries successfully added.
        """
        added: int = 0
        for font in fonts:
            font_id: str = self._unique_id(font.manifest_id)
            font.manifest_id = font_id
            self._existing_ids.add(font_id)

            item: ET.Element = ET.SubElement(self._manifest, "item")
            item.set("id", font_id)
            item.set("href", font.href)
            item.set("media-type", font.media_type)
            item.set("properties", "remote-resources")

            added += 1

        return added

    def _unique_id(self, candidate: str) -> str:
        """Return *candidate* if unused; otherwise append a counter suffix.

        Parameters
        ----------
        candidate : str
            Proposed manifest ID.

        Returns
        -------
        str
            A unique ID based on *candidate*.
        """
        if candidate not in self._existing_ids:
            return candidate
        counter: int = 1
        while f"{candidate}-{counter}" in self._existing_ids:
            counter += 1
        return f"{candidate}-{counter}"

    # ------------------------------------------------------------------
    # Persistence
    # ------------------------------------------------------------------

    def save(self, opf_path: Path) -> None:
        """Write the modified OPF back to disk.

        Parameters
        ----------
        opf_path : Path
            Destination path.
        """
        self._tree.write(str(opf_path), xml_declaration=True, encoding="utf-8")


class EpubPackager:
    """Package an unpacked EPUB directory into a valid ``.epub`` archive.

    This class has no instance state; all methods are static.
    """

    @staticmethod
    def package(epub_dir: Path, output_path: Path) -> None:
        """Create an EPUB archive from an unpacked directory.

        The ``mimetype`` file is placed **first** in the archive with
        ``ZIP_STORED`` (no compression), which is required by the EPUB
        specification.

        Parameters
        ----------
        epub_dir : Path
            Root of the unpacked EPUB (must contain ``mimetype``,
            ``META-INF/``, ``OEBPS/``, etc.).
        output_path : Path
            Desired location for the generated ``.epub`` file.

        Raises
        ------
        FileNotFoundError
            If *epub_dir* does not exist.
        """
        if not epub_dir.is_dir():
            raise FileNotFoundError(f"EPUB directory not found: {epub_dir}")

        with tempfile.TemporaryDirectory() as tmpdir:
            zip_path: Path = Path(tmpdir) / "temp.epub"

            with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
                EpubPackager._write_mimetype_first(zf, epub_dir)
                EpubPackager._write_remaining_files(zf, epub_dir)

            output_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(str(zip_path), str(output_path))

    @staticmethod
    def _write_mimetype_first(
        zf: zipfile.ZipFile,
        epub_dir: Path,
    ) -> None:
        """Write the ``mimetype`` entry first, uncompressed.

        Parameters
        ----------
        zf : zipfile.ZipFile
            Open ZIP archive.
        epub_dir : Path
            Root of the unpacked EPUB.
        """
        mimetype_file: Path = epub_dir / "mimetype"
        if mimetype_file.is_file():
            zf.write(
                str(mimetype_file),
                "mimetype",
                compress_type=zipfile.ZIP_STORED,
            )

    @staticmethod
    def _write_remaining_files(
        zf: zipfile.ZipFile,
        epub_dir: Path,
    ) -> None:
        """Write all files except ``mimetype`` into the ZIP archive.

        Parameters
        ----------
        zf : zipfile.ZipFile
            Open ZIP archive.
        epub_dir : Path
            Root of the unpacked EPUB.
        """
        for child in epub_dir.rglob("*"):
            if not child.is_file():
                continue
            if child.name == "mimetype":
                continue
            rel: str = str(child.relative_to(epub_dir))
            zf.write(str(child), rel)


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


class EpubFontInjector:
    """High-level orchestrator that runs the full font-injection pipeline.

    Usage
    -----
    This class is not instantiated.  Call :meth:`main` directly::

        $ python3 fix_epub_fonts.py epub_work output.epub
    """

    @classmethod
    def _build_argument_parser(cls) -> argparse.ArgumentParser:
        """Construct the argument parser for the script.

        Returns
        -------
        argparse.ArgumentParser
            Configured parser with ``epub_directory`` (required) and
            ``output_epub`` (optional) positional arguments.
        """
        parser: argparse.ArgumentParser = argparse.ArgumentParser(
            description=(
                "Inject embedded fonts into the OPF manifest of an "
                "unpacked EPUB and re-package it."
            ),
        )
        parser.add_argument(
            "epub_directory",
            metavar="EPUB_DIR",
            help="Path to the unpacked EPUB directory.",
        )
        parser.add_argument(
            "output_epub",
            metavar="OUTPUT_EPUB",
            nargs="?",
            default=None,
            help=(
                "Destination for the generated EPUB file. "
                "Defaults to EPUB_DIR.epub in the parent directory."
            ),
        )
        return parser

    @classmethod
    def main(cls, *args: str) -> int:
        """Run the font-injection pipeline.

        Parameters
        ----------
        *args : str
            Command-line arguments (as passed by ``sys.argv[1:]``).

        Returns
        -------
        int
            ``0`` on success, ``1`` on error.
        """
        parser: argparse.ArgumentParser = cls._build_argument_parser()
        parsed_args: argparse.Namespace = parser.parse_args(args if args else None)

        epub_dir: Path = Path(parsed_args.epub_directory)
        output_path: Path = (
            Path(parsed_args.output_epub).resolve()
            if parsed_args.output_epub
            else epub_dir.parent / f"{epub_dir.name}.epub"
        )

        # ---- Validate ----
        fonts_dir: Path = epub_dir / "OEBPS" / "fonts"
        opf_path: Path = epub_dir / "OEBPS" / "content.opf"

        if not fonts_dir.is_dir():
            print(
                f"Error: fonts directory not found: {fonts_dir}",
                file=sys.stderr,
            )
            print("Did you copy the fonts into place?", file=sys.stderr)
            return 1

        if not opf_path.is_file():
            print(
                f"Error: OPF file not found: {opf_path}",
                file=sys.stderr,
            )
            return 1

        # ---- 1. Discover fonts ----
        try:
            fonts: list[FontFile] = FontFile.discover(fonts_dir)
        except FileNotFoundError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        if not fonts:
            print(
                f"Error: no font files found in {fonts_dir}",
                file=sys.stderr,
            )
            return 1

        print(f"Fonts discovered: {len(fonts)}")
        for f in fonts:
            print(f"  {f.font_path.name}  →  {f.media_type}")

        # ---- 2. Inject into manifest ----
        try:
            manifest: OpfManifest = OpfManifest.load(opf_path)
        except (FileNotFoundError, ValueError) as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        added: int = manifest.add_font_entries(fonts)
        manifest.save(opf_path)

        print(f"\nManifest updated: {added} font entry(ies) added")

        # ---- 3. Re-package ----
        print(f"\nRe-packaging EPUB → {output_path}")
        try:
            EpubPackager.package(epub_dir, output_path)
        except FileNotFoundError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return 1

        print(f"EPUB generated: {output_path}")
        print("Done!")
        return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    sys.exit(EpubFontInjector.main(*sys.argv[1:]))
