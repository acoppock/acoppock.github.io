# Port audit: what the old generator knows that the new layer does not

Run 2026-07-30, before Phase 3, because the Phase 2 slice reintroduced a defect that had already been fixed once. The brace bug was fixed on 2026-07-29 inside `clean_projects.R`, and a new reading layer brought it straight back, in the page heading and the browser tab, exactly as before.

**The governing point: a fix that lives in the reader is not inherited by a new reader.** `clean_projects.R` and `make_project_pages.R` hold roughly a year of accumulated corrections, most of them invisible from the data. Migrating 57 folders before porting them means meeting each one again as a broken page.

Read: `clean_projects.R` (129 lines), `make_project_pages.R` (194), `make_bib_files.R` (78), `make_gallery_pages.R` (301), `make_card_images.R` (68).

## Already ported during Phase 2

| Fix | Where it lived | Where it lives now |
|---|---|---|
| Strip double braces from `TITLE` (39 of 72 entries) | `clean_projects.R:75` | `strip_bib_braces()` in `harvest_works.R` |
| Strip the stray `}` bib2df leaves on an entry's final field (41 entries) | `clean_projects.R:69`, and again in `make_bib_files.R:26` | same |

**Correction to the Phase 2 log entry:** the trailing-brace defect was NOT undocumented. It is called out in a comment at `clean_projects.R:69` and handled a second time by `clean_value()` in `make_bib_files.R`. What the slice actually demonstrated is narrower and more useful: a known, twice-fixed defect reappeared because both fixes lived in readers being replaced.

## Not ported. These are the Phase 3 blockers

**1. The `.bib` trailing blank line, and it is the dangerous one.** `clean_projects.R:17-21` **writes to `bibliography.bib`** to guarantee it ends with a blank line, because `bib2df` silently drops the final field of the final entry otherwise. Nothing errors; the field returns `NA`. The file satisfies the invariant today only because that script has been run. **BibDesk rewrites the file**, so the invariant decays on its own, and `harvest_works()` does not restore it. If the new layer replaces `clean_projects.R` without carrying this, the last entry in the bib quietly loses a field, and which entry that is changes as entries are added. The known instance cost `aronow_etal_2015` its DOI link for a week.

**2. `unlatex()`, 38 accent mappings.** `clean_projects.R:26-41` converts BibTeX accent macros to UTF-8 so `Avi{\~n}a` renders as `Aviña`. The harvester has nothing equivalent, so any accented coauthor name would reach the page as raw LaTeX.

**3. `format_authors()` differs from what the slice does, in four ways.** `clean_projects.R:45-56` inverts the first author, keeps the rest natural, and joins three or more with an Oxford comma (`A, B, and C`). It also folds in `middle_name` and `suffix`, and applies `unlatex`. The slice's version omits the Oxford comma, drops `suffix`, and does not unlatex.

**4. The venue fallback chain.** `status = coalesce(JOURNAL, NOTE, BOOKTITLE, PUBLISHER, TYPE, SCHOOL)` at `clean_projects.R:67`. The slice handles only `JOURNAL` and `PUBLISHER`, so a chapter (`BOOKTITLE`), a dissertation (`TYPE`, `SCHOOL`) and software (`NOTE`) all lose their venue. `TYPE` and `SCHOOL` were added on 2026-07-29 precisely because the dissertation's citation read "... Response to Information. NA."

**5. `YEAR` brace strip** (`clean_projects.R:68`), the same artifact as the DOI.

**6. Trailing period removed from the author list** before the citation appends `". "` (`clean_projects.R:77`), which otherwise yields `Green.. 2016`.

**7. Page ranges.** `gsub("-+", "&ndash;", PAGES)` collapses any run of hyphens; the slice replaces only a literal `--`, and only the first occurrence.

**8. Abstracts must be read with `read_file`, not line-wise.** `clean_projects.R:104-112` records that `readLines` broke on multi-paragraph abstracts. One file is genuinely multi-paragraph today (`coppock_2016b.txt`, the dissertation). The slice reads lines and joins them with blank lines, which would turn a wrapped single paragraph into several.

**9. Omit a section rather than print `NA`.** `make_project_pages.R:49-51`: the Abstract heading is emitted only when there is an abstract. It used to be part of the template, and **12 pages rendered a section containing the literal string "NA"**. The slice emits the heading unconditionally. The principle is worth carrying beyond this one section: an absent abstract is a content gap to fill, and a page that says "NA" hides it behind something that looks deliberate.

**10. The Links block's blank-line discipline.** `make_project_pages.R:53-68`: emit `\n# Links\n\n` so the section does not depend on what precedes it, keep the items contiguous, and build every item from one template. All three exist because of real defects: an abstract ending in a single newline let pandoc absorb the heading and render every link inline; a stray `cat("\n")` split one list into two; and eight of nine hand-written links had a malformed `href='...'target='_blank'`.

**11. The card fallback.** `make_gallery_pages.R:30-33` picks `item_stub_no_card` when no card file exists, which is what lets a book or a package with no hex render as a linked title instead of a broken image.

**12. The card recipe itself.** `make_card_images.R`: papers are page 1 of the PDF at density 500, scaled to 1000 and cropped square; **covers are resized and padded onto a white 1000x1000 canvas rather than cropped**, because cropping a cover cuts off the title or the author. Two different recipes for two asset roles, which the `assets` map now has a place to record.

## Survives the migration unchanged

**`make_bib_files.R`.** It parses `bibliography.bib` directly with its own reader, keeps a canonical field list, is idempotent, and deletes stale files. It never reads `projects_clean.csv`, so it is independent of the layer being replaced. The Phase 2 note that Quarto "needs an equivalent of `make_bib_files.R`" was wrong: the new site should simply run it and copy `bibliography/separate_bib_files/<key>.txt` into the output root.

## STATUS: all twelve closed, 2026-07-30

| # | Item | How it was closed |
|---|---|---|
| 1 | `.bib` trailing blank line | **Retired.** `read_bib()` counts braces, so the final field of the final entry parses correctly with no file mutation. The harvester stays read-only and the assertion is unnecessary. |
| 2 | `unlatex()` accents | **Superseded.** Accent commands map to Unicode combining marks and NFC-compose, covering every letter rather than 38 enumerated pairs. |
| 3 | `format_authors()` | Ported to `build_slice.R`: first author inverted, rest natural, Oxford comma at three or more. |
| 4 | Venue fallback | Ported: `coalesce(journal, note, booktitle, publisher, type, school)`. |
| 5 | `YEAR` brace strip | Retired by the parser. |
| 6 | Trailing period on the author list | Ported. |
| 7 | Page ranges | Ported, emitting a real `–` rather than the `&ndash;` entity. |
| 8 | Abstracts via `read_file` | Ported. |
| 9 | Omit a section rather than print `NA` | Ported, and generalized: sections are assembled as a list and empty ones are dropped. |
| 10 | Links blank-line discipline | Ported **structurally**. Sections are joined by a blank line rather than managed by hand, so no section can depend on what the previous one left behind. Every link is still built from one template, so the malformed `href` remains unrepresentable. |
| 11 | Card fallback | Ported to the Software listing, keyed on **the file existing on disk** rather than on a record. Verified on all three branches: card present renders an image; card recorded but file missing falls back; no card recorded falls back. |
| 12 | Card recipes | Recorded per asset, not reimplemented. `make_card_images.R:paper` (page 1, density 500, scaled to 1000, **cropped**) and `make_card_images.R:cover` (**fitted and padded** onto a white square, because cropping a cover cuts off the title). `recipe: null` marks the hand-made hexes. |

The slice renders after every one of these, and `check_works()` returns 0 errors.

## What this changes about Phase 3

Port items 1 through 8 into `harvest_works()`, since they are all bib normalization and belong with the reader. Items 9 through 11 are template behaviour and belong in the page builder. Item 12 is an asset recipe and should be recorded per asset rather than reimplemented.

Item 1 deserves its own decision and is the only one that cannot simply be copied: **either the new layer keeps normalizing the file on read, or the invariant moves into a check that fails loudly.** Normalizing means the harvester is no longer pure, which is the property that makes it testable. A `check_works()` assertion that the bib ends with a blank line is the better shape, since it turns a silent data-loss bug into a visible failure and keeps the reader read-only.
