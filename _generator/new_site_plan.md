# The new site — plan

Drafted 2026-07-29 (Claude), after a session spent finding out what `works/` already is. Companion to `LOGFILE.md`, which records that session. Nothing here is built.

Sibling document: `the_library/notes/architecture.md`. This plan deliberately inherits its governing rule and its vocabulary rather than inventing a second set, because the two projects converge: a paper folder here and a study folder there are the same idea at different grain, and the ingest protocol `vn_20` wants is `write_study_yaml()` one level up. **One schema habit, one emitter habit, two consumers.**

## Decisions already taken (do not re-propose)

- **`works/` stays in Dropbox.** Not under git (Alex, 2026-07-29). Version history is the recovery path; the plan's phase 0 is therefore about removing ambiguity between four copies of one spreadsheet, not about adding a VCS.
- **The Notes page stays hand-curated.** A generated `kind: note` listing would publish whatever sits in `subpages/`, and two notes there are deliberately unlinked pending Alex's decision. The editorial judgment about what is ready to show is the point of the page.
- **`assets/` is a fourth per-paper folder and holds all four asset types, cards included.** Decided 2026-07-29 after Alex objected to my keeping cards out of it. Two of my three arguments were bad and are withdrawn; the deciding one is that 13 of 62 cards have no source, so a derived-lives-elsewhere rule needs an exception list, and exception lists are what this reorganization exists to eliminate. Full reasoning under Layer 1.
- **The R packages are works**, carried as `kind: software` (Alex, 2026-07-29), and there will be more than five. The field scales without change; `vayr` joins the page for free. What the extra packages lack is planned for under "Software as works" below: no hexes exist in any repo, nine of fifteen have no CRAN DOI, and six have no pkgdown site.
- **The CV keeps rendering directly from `bibliography.bib`**, with no intermediate file (Alex, 2026-07-29). The field-ownership split therefore stands, and the site knowingly has two hand-edited layers rather than one, made safe by the `check_works()` bijection assert.
- **Software gets no project page, only a link out to its pkgdown site** (Alex, 2026-07-29). Shipped `228cdf0`. The gallery always linked straight out, so the generated pages were orphans nothing linked to, and their one unique feature was redundant: **pkgdown already serves a citation page with a BibTeX block at `<site>/authors.html`**. `make_project_pages.R` now excludes software by bib `CATEGORY` rather than by a list of package names, so a new package is excluded by existing rather than by being remembered. Ten pages and their bibtex files removed; the ten gallery entries are unaffected.
- **The four Phase 1 schema questions are closed** (Alex, 2026-07-30, structured choice): `links` keeps its named keys AND gains a labelled `extra:` list; `coauthors_by_hand.xlsx` gains a `slug` column and `paper.yaml` keys on it; the bare `display_figure` becomes an `assets:` map covering display, card, cover and hex, each carrying its `recipe`; and glosses are DRAFTED by Claude for Alex to edit rather than left blank. Full reasoning under the metadata contract. The one that mattered most is `extra:`, because without it `custom_pages` survives the restructure.
- **Reviews of Alex's work stay in `bibliography.bib`, and a bib entry with no paper folder is a LEGAL state** (Alex, 2026-07-30). He first took the view that `carlson_2023` and `Levendusky2023` do not belong in the bib, not having written them, and the CV settled it: `coppock_cv.tex:125-126` cites both through `\bibentry{}` as sub-items under the book, labelled "Review:" beside the Lane Award, which is the conventional way to list reviews of one's own book. Removing them would force those two citations to be hand-typed in the `.tex`, the same duplication moved somewhere BibDesk cannot maintain. **The rule this establishes: the bib's scope is defined by its consumer rather than by authorship** — it holds what the CV needs to cite. So `check_works()` must REPORT bib entries with no folder for review rather than fail on them, which is the job the retired `not_my_work` list was actually doing. Accepted cost: those two citations exist both in the bib and as prose in `coppock_2022/metadata/custom.md`, and the `custom.md` copy is the one that will go stale.
- **Books and articles keep their pages, and custom content stays supported.** Reaffirmed 2026-07-29. `metadata/custom.md`, appended verbatim, is how reviews reach the Persuasion in Parallel page and how anything else bespoke reaches any page. Unchanged from the original draft; restated because the software decision above could otherwise read as narrowing pages in general.
- **A package goes on the CV if and only if it is on CRAN** (Alex, 2026-07-29). Already true when the rule was set: the CV's Software section listed exactly the six CRAN packages and none of the four GitHub-only ones. The rule matters because it has a **trigger** rather than being static: a package graduating to CRAN should join the CV at that moment, and nothing would otherwise notice, since the Software section is hand-curated LaTeX. Enforced by `claude_control/tools/check_cv_software.R`, which queries CRAN live rather than recording status anywhere, and is run after any CRAN acceptance and before circulating the CV. **Next time it fires:** the Zero packages, whose submission order is already fixed as fabricatrZero then DeclareDesignZero.
- **`on_cv` is gone from `projects_by_hand.xlsx`** (Alex, 2026-07-29: "those decisions get made in the tex, not in the xlsx"). It was dead and wrong: no script anywhere read it, and it marked ri2 `no` while ri2 was on the CV (38 yes / 20 no / 13 NA across 71 rows, against 52 `\bibentry` calls). **Proven inert by behaviour rather than by grep:** after dropping the column, `projects_clean.csv` differed only by that column and **no site file changed at all**, so it had been a write-only passthrough. The `.tex` is the one place CV membership is decided, and `check_cv_software.R` verifies the CRAN rule against it. First field this project has removed rather than added, and the right kind of removal.
- **Published URLs do not change. The site keeps publishing flat.** Decided 2026-07-29, and it retires what this plan had called its one blocking decision. Two independent things had been conflated: the **source** layout and the **published URL** layout. The build step decides where output lands, so `works/` restructures into per-paper folders while every published URL stays byte-identical. `vn_20`'s worry that a nested source would force a nested `/<paper_id>.pdf` is unfounded for that reason.

  The mechanics settle it rather than taste. GitHub Pages serves static files and has **no server-side 301**: no `.htaccess`, and no `_redirects` (that is Netlify and Cloudflare). Of the **252 citable URLs** at the root today, **108 are PDFs, and a PDF URL cannot be redirected on Pages by any method**, because Pages sets `Content-Type` from the extension, so a meta-refresh HTML file sitting at `<paper_id>.pdf` is served as `application/pdf` and fails to render. A `.pdf` URL either serves PDF bytes or 404s. Those 108 are also the URLs most likely to sit in someone else's syllabus, reading list, or printed citation, where they can never be updated.

  The flat published root was never the defect `vn_20` described. What it described was the *source* being an unnavigable pile of 319 files, which is exactly what this restructure fixes. Nobody browses a published root as a directory listing, so its flatness costs readers nothing while its stability is worth a great deal: a public URL is a promise, and there are 252 outstanding with no way to keep 108 of them through a move.

  Should `/works/<paper_id>/` ever be wanted anyway, the honest path is moving hosting to Cloudflare Pages or Netlify for real 301s, keeping the PDFs at their current paths permanently regardless, and treating the remainder as cosmetic. Not recommended.

## The governing rule, restated for this site

**Layers, and every layer is a pure function of the layer below.** The paper folders are the only place a human edits anything. The manifest is derived from the folders, the pages from the manifest, the site from the pages. Nothing downstream is ever hand-edited, and the whole site can be deleted and rebuilt.

The rule is not aspirational here, it is the diagnosis. Every defect the 2026-07-29 session found had one cause: **the same fact stored in more than one place.** Each paper's citation existed three times (project page, gallery entry, bibtex file). The title existed as a braced bib field and an unbraced citation string, and the second was stripped while the first was not, which put a literal `{...}` in the browser tab of 35 live pages. Figures existed under a draft year and a published year. Sixteen pages existed that no gallery knew about. A review of Alex's own book was served as one of his works because a single exclusion list was doing three unrelated jobs.

None of those was a hard bug. Each was a second copy drifting from the first. The new structure earns its cost only if it removes the copies, so every decision below is tested against one question: **does this leave the fact in exactly one place?**

## What stays shared

Not everything is per-paper, and pretending otherwise is how a reorganization goes wrong. These stay as they are, at the top level:

- `bibliography/` — `bibliography.bib` remains the canonical source for **citation** metadata. Discussed below; it is the one deliberate exception to the one-hand-edited-layer rule, and it is exception-by-evidence rather than by convenience.
- `curriculum_vitae/` — the CV LaTeX, which reads the bib. Not a paper.
- `data/citations.csv`, `self_citations.xlsx` — Scholar citation tracking, a cross-paper time series fed by `get_scholar_info.R`.
- `site/` — templates, CSS, and the genuinely hand-written pages (home, notes).
- `code/` — the generator.

## LAYOUT CHANGED 2026-07-30: the paper folders live under `original_materials/`

Alex, after seeing 70 folders land at the top of `works/`: the project folders belong inside an `original_materials/` subfolder. Done, and the code follows it through a single `works_dir()` helper.

```
works/original_materials/<paper_id>/metadata/paper.yaml
```

**This inverts what the section below describes.** The original sketch put `original_materials/` INSIDE each paper folder, alongside `metadata/`, `code/` and `assets/`. The new arrangement keeps `works/` legible, since the top level is now 14 directories rather than 84, and it matches the `original_materials/<paper_id>/` convention the meta-analysis projects already use, where that folder holds `<paper_id>.pdf`, `<paper_id>_appendix.pdf` and `<paper_id>_notes.txt`.

**What is not yet decided, and the text below is stale until it is:** whether a paper's PDFs, assets and code move into `original_materials/<paper_id>/` beside `metadata/`, and whether `metadata/` stays a subfolder or its contents sit directly in the paper folder. Nothing has moved yet: the PDFs are still in the flat `documents/`, and the figures in `display_figures/`, `card_figures/` and `book_covers/`. Only `paper.yaml` and `custom.md` have relocated.

## Layer 1: the paper folder

```
works/<paper_id>/
  metadata/
    paper.yaml            # the hand-authored metadata, the only expensive artifact
    abstract.md           # prose, kept out of YAML where it reads badly
    custom.md             # OPTIONAL, appended verbatim to the generated page
  original_materials/
    <paper_id>.pdf
    <paper_id>_appendix.pdf
    <paper_id>_notes.txt  # carries the DOI line, per house convention
    <paper_id>_working_paper.pdf     # superseded versions, kept, never deleted
    replication_archive/  # as deposited, verbatim
    recovered/            # files the authors supplied that the archive omitted
  code/
    ...                   # the maintained rewrite, ground_truth/, report/
  assets/
    <paper_id>_display.png
    <paper_id>_card.png
```

`paper_id` conventions, the notes-file conventions, and the keep-superseded-versions rule all carry over unchanged from `claude_control/CLAUDE.md`. Nothing here is new except `paper.yaml`, `custom.md`, and the requirement that a paper's things sit in one place.

**`original_materials/` must preserve the `original/` versus `recovered/` distinction** that `active_maintenance_aec` already draws. It is not housekeeping: `coppock_2026` argues about how far the archived record falls short of the paper, and collapsing "as deposited" into "as deposited plus what the authors emailed later" destroys the evidence for that argument. Flattening it would be a substantive error, not a tidying choice.

**`assets/` is a fourth folder. DECIDED 2026-07-29, and it holds all four asset types including the cards.** Alex named three folders; the fourth earns its place because the alternatives both fail. Folding these into `original_materials/` would call a figure Alex drew part of the paper's *received* record, which is the one distinction that folder exists to protect. Requiring `code/` to generate them is right in the long run and impossible now, since **no script anywhere writes `display_figures/`** and 23 papers have no maintained code at all.

```
works/<paper_id>/assets/
  <paper_id>_display.png     # the headline figure. 39 exist, ZERO have a recipe
  <paper_id>_card.png        # 49 of 62 regenerable by make_card_images.R
  <paper_id>_cover.jpg       # books only
  <paper_id>_hex.png         # software only, the package logo
```

### Why the cards go here too, having first argued they should not

An earlier draft of this plan kept cards out of `assets/`, on the grounds that a card is build output with a recipe while a display figure is irreplaceable source. Alex objected: everything in `assets/` gets copied to the published tree anyway, so what distinguishes the card? He was right, and the objection took down most of the argument.

**Withdrawn as bad arguments:** that excluding cards avoids storing them twice, and that it avoids drift. The display figure, cover, hex and PDF all land in the published tree too, so both properties belong to the whole scheme rather than to the card, and neither discriminates.

**The one argument that survived:** a card is the only one of the four that is purely presentational, so it is the only one a facelift changes. Generated at build time, a change of card treatment is one edit; stored, it is 49 regenerations plus a re-commit, and a half-finished pass leaves old-recipe and new-recipe cards that nothing can tell apart.

**What outweighed it:** **13 of the 62 cards have no source on disk** (5 hand-made package hexes, 4 items of site content with no paper, 4 stale or orphaned). "Cards are derived" is therefore false for 21% of them, so the rule is really a rule plus an exception list — and exception lists are precisely what this reorganization exists to eliminate, since each of today's five hardcoded lists caused or nearly caused a defect. The facelift argument also shrinks on inspection: those 13 need hand re-cropping at facelift time wherever they live, so generating at build does not remove the problem, only reduces it from 62 files to 13.

**And the deeper reason.** The thesis of the restructure is **organize by paper, not by type**, which is why `abstracts/`, `display_figures/`, `card_figures/` and `documents/` are being dissolved. Excluding the card because it is a different *kind* of file smuggles type-based organization back in. Location should follow what a file is a thing *of*, which is this paper; how it came to exist is a property of the file, not a reason to file it elsewhere.

Cost: 32MB of cards on a 226MB tree.

**What survives of the source-versus-derived distinction, because it is still real:** it belongs in metadata, not in the directory layout. Record per asset whether a recipe exists, so it is knowable which files can be afford to be lost. **The 39 display figures and the 5 hexes are the ones that cannot**, and they are what needs backing up.

Option 3 is the destination; option 1 is the way to get there without blocking on 23 rewrites.

## The metadata contract

`paper.yaml` is the one thing expensive to get wrong, because everything downstream reads it and every change is a migration across 60 folders. Two rules, taken from the Library architecture: spend disproportionate effort on it now, make it additive-only afterward.

**SETTLED 2026-07-30 against three hand-written cases.** The block below is the schema as it stands after Phase 1, not the original sketch; three of its shapes changed because `coppock_2022`, `ri2` and `coppock_green_2016` broke the sketch.

```yaml
paper_id: coppock_green_2016
bibtex_key: coppock_green_2016     # join key into bibliography.bib
kind: article                      # article | book | chapter | software | note
stage: published                   # published | working | staged
links:
  paper: coppock_green_2016.pdf
  appendix: coppock_green_2016_appendix.pdf
  journal: https://doi.org/10.1111/ajps.12210
  replication_archive: https://doi.org/10.7910/DVN/XXXXX
  preanalysis_plans: []
  project: null
  extra:                           # labelled, ordered, for anything unnamed
    - label: Chapter 1
      file: persuasion_in_parallel_chapter_1.pdf
    - label: Link to press
      url: https://press.uchicago.edu/...
coauthors: [donald_green]          # slug into data/coauthors_by_hand.xlsx
assets:                            # all four types, with the recipe fact
  display:
    file: coppock_green_2016_display.png
    recipe: null                   # null means no script regenerates it
    gloss: >
      One sentence on what the figure shows and why it is the paper's
      headline. vn_20 asks for this; no current page has it.
  card:
    file: coppock_green_2016_card.png
    recipe: make_card_images.R
  cover: null                      # books only
  hex: null                        # software only
rights: public                     # per Library design notes 6.3
active_maintenance: complete       # none | in_progress | complete
```

**What the three hard cases changed, and why each was not visible from the sketch.**

- **`links.extra` exists because `coppock_2022` has four links the fixed set cannot name** (Chapter 1, the conversation among critics, the press page, Amazon). Without it the book keeps a bespoke template and `custom_pages` is NOT retired, so one of the five hardcoded lists survives the restructure and the plan's headline claim quietly weakens to four. The named keys stay, so `check_works()` can still assert that a published article has a journal link.
- **`coauthors` keys on a slug because the sketch's `[donald_green]` did not exist.** `coauthors_by_hand.xlsx` keyed on `full_name` only. A `slug` column was added 2026-07-30 (64 rows, 64 unique slugs, no collisions, `Donald P. Green` -> `donald_green`), the old file archived, and the change proven behaviour-neutral: coauthor links are byte-identical for `coppock_green_2016`, `blair_coppock_humphreys_2023` and `peyton_huber_coppock_2022`. The join in `make_project_pages.R` is `by = "full_name"` against the BIB's author table, not against `projects_df`, so the new column collides with nothing.
- **`display_figure` became `assets` because a book has no figure.** `coppock_2022_display.jpg` turned out to BE the book cover, and `blair_coppock_humphreys_2023` has a cover and no display figure at all, which is the consistent shape. So `kind: book` renders a cover in the slot an article gives its figure, **and a book has no gloss to write** — a quiet reduction in the 60-gloss rate limit. The map also gives the source-versus-derived argument its promised home: `recipe: null` is what records that all 13 recipe-less assets, including every package hex, exist only in the website tree.

**Found while writing them, and not yet acted on:** `coppock_2022`'s cover is stored twice, as `display_figures/coppock_2022_display.jpg` (267KB) and `book_covers/coppock_2022_cover.jpg` (156KB), same image at different resolutions and different md5. The higher-resolution copy is named as the cover. Neither is deleted, since no script regenerates either.

### Why the bib stays canonical, and why that is not a second copy

The one-hand-edited-layer rule says citation metadata should live in `paper.yaml`. It should not, and the reason is a consumer the site does not own: `bibliography.bib` is BibDesk-managed and the CV renders from it with `\nocite{*}`. Moving citations into 60 YAML files would either break the CV or require generating a bib from the YAML, which is the same duplication pointed the other way, with a worse editor.

So the boundary is drawn by **field ownership rather than by file**: the bib owns author, title, journal, year, volume, number, pages, DOI, and nothing else; `paper.yaml` owns links, kind, stage, figure, gloss, rights, and never restates a bib field. The join is `bibtex_key`. No fact lives twice, which is the test that matters, and the arrangement is enforceable rather than merely intended:

**`check_works()` asserts the bijection.** Every paper folder has exactly one bib entry and every bib entry that is Alex's work has exactly one folder. That check alone catches four things found by hand today: `coppock_galos_2024` (a page and a bibtex file with no bib entry, almost certainly a stale artifact of a key rename), `brodeur_etal_2024` (id says 2024, entry says Nature 2026), `coppock_green_porter_20XX` (a literal placeholder), and the two reviews sitting in the works pipeline at all.

## The transposition: two fields retire five hardcoded lists

This is the plan's best return, and it is worth stating concretely because it is easy to under-sell a schema change as mere tidying.

| Today | Tomorrow |
|---|---|
| `no_page_yet` (10 keys) | `stage: staged` |
| `custom_pages` (`coppock_2022`) | presence of `metadata/custom.md` |
| `not_my_work` (2 reviews) | no folder exists; they are bib-only, and `check_works()` says so |
| `make_gallery_pages.R`'s hand-ordered run of 38 `make_entry()` calls | a Quarto listing sorted by year |
| `software.rmd`'s 5 hardcoded `make_software_entry()` calls | `kind: software` |
| the Books/Articles split added today | `kind: book` versus `kind: article` |
| `working_papers` vector + empty-state branch | `stage: working`, and the listing's own empty state |

Every one of those lists is a place where a fact about a paper lives somewhere other than with the paper, and every one of them has already caused a defect or is one edit away from causing one. `vayr` is the clean demonstration: it is an R package on the site whose page nobody links, because adding it required remembering to edit a hardcoded list in a second file. Under `kind: software` it appears the moment its folder exists.

**Reviews stay unmodelled**, per Alex 2026-07-29. They are rare enough that a schema for them costs more than it returns, so they live in the reviewed work's `custom.md`. Recorded so nobody proposes a `reviews:` field later.

## Layer 2: the manifest

`harvest_works()` walks the paper folders, reads every `paper.yaml`, joins the bib on `bibtex_key`, and returns tidy tables: `papers`, `links`, `coauthors`, `assets`. Pure: reads, writes nothing.

**Not DuckDB.** The Library needs a queryable catalog because a meta-analysis is a query over it and it ships to the browser. This site needs 60 rows joined to a bib, which is a tibble. A DuckDB file here would be architecture cosplay. `build_manifest()` writes one `.rds` (or `.csv` for legibility) and the Quarto pages read it.

The pointed version: **the manifest is `projects_clean.csv` with its inputs turned sideways.** That file already exists and already works. What changes is not the shape of the derived table but that its inputs stop being one 17-column spreadsheet row per paper, sitting in a folder no paper owns.

## Layer 3: Quarto rendering

One `.qmd` template per `kind`, rendered over the manifest, plus the hand-written pages.

Quarto supplies free what the current stack does by hand or not at all: **listings** (which is the entire job of `make_gallery_pages.R`, including the empty state added today by hand), full-text search across the site, cross-references, and a sane include mechanism instead of `<!--html_preserve-->` and three `include_*.html` fragments injected by `_site.yml`.

What Quarto costs, stated honestly:

- **The home page is bespoke, but it is not Bootstrap-coupled.** Corrected 2026-07-29 after checking: `index.Rmd` uses **zero Bootstrap classes**. `band full blue first leftText`, `bandContent vCenter`, `blurb` and `imageTwo` are all defined in `css/rmarkdown.css`, which is 921 lines containing **zero** Bootstrap grid, navbar or button override selectors, and the nav is custom too (`menuItem`, 27 rules). Bootstrap 3 is a typography baseline and little else here, so the site's visual identity is framework-independent CSS that ports largely as-is. An earlier draft of this plan called the home page a real porting cost; that was overstated.
- **URLs must not change, and this is now a build requirement rather than an open question** (see the decisions section). Quarto's default `_site/` output differs from the current `output_dir: '.'`, so the project has to be configured to publish flat: pages at `/<paper_id>.html`, PDFs and bibtex files at the root beside them, whatever the source tree looks like. **Assert it in the build.** A test that every one of the 252 URLs present before the migration is still present after it is worth more than any amount of care, because the failure is silent and the damage is other people's broken links. The pre-migration list is captured at `notes/published_urls_20260729.txt` (252 lines, taken 2026-07-29 from the live tree, `include_*` fragments excluded); **the migration is not done until a rebuilt site contains every line in it.**
- **The `.txt` bibtex download** on every project page is a real feature (it is what "Bibtex citation" links to) and needs a Quarto-side equivalent of `make_bib_files.R`.

## Why Quarto rather than R Markdown, and how the package sites become coherent

Asked directly on 2026-07-29: is Quarto actually better here, given the goals are a facelift and having `alexandercoppock.com/metaprep` feel of a piece with the parent site. The answer is yes, and the reason is the second goal specifically rather than anything generic about Quarto being newer.

Measured, not recalled:

| | Bootstrap |
|---|---|
| `alexandercoppock.com` today (R Markdown, `site_libs/`) | **3.3.5** |
| Quarto 1.10.18 | **5.3.1** |
| all five pkgdown sites | **5.3.8** |

The main site and the package sites are **two generations apart**, on different SASS variable names and a different grid. That is why `/metaprep` does not feel coherent, and why it cannot be made coherent durably as things stand: matching a Bootstrap 3 site to Bootstrap 5 ones means hand-matching forever, re-matching at every pkgdown release.

**The mechanism that fixes it.** pkgdown 2.x themes through `template: bslib:` in `_pkgdown.yml` plus an optional `pkgdown/extra.scss`; Quarto themes through `theme: [<bootswatch>, brand.scss]` in `_quarto.yml`. **Both consume Bootstrap 5 SASS variables under identical names** (`$primary`, `$body-color`, `$link-color`, `$font-family-sans-serif`, `$border-radius`). So a single `brand.scss` drives all six sites, copied into each package repo or carried as a submodule. Put the main site on Quarto and coherence becomes a shared variables file; leave it on Bootstrap 3 and coherence stays a manual imitation.

Today's gap in miniature: `metaprep` sets `primary: "#1f6f8b"` and the other four packages set nothing, so even the package sites do not match **each other**. Whatever `brand.scss` ends up saying should land in all five `_pkgdown.yml` files in the same pass.

**The honest counter-argument.** If generated project pages were the only goal, `rmarkdown::render_site()` works today and there would be no urgency at all. Quarto's listings (which retire `make_gallery_pages.R` outright) and its built-in search are real but secondary. The case rests on the facelift and the package coherence, and neither is well served by Bootstrap 3.

**Sequencing, and this matters more than the choice of tool: keep the facelift and the restructure as separate passes.** Do the restructure first with the current look ported as-is, so that verifying it means checking that all 252 URLs still resolve and that nothing looks different. Then facelift as its own deliberate act, with `brand.scss` and the five `_pkgdown.yml` files changing together. If both land at once, every odd-looking page is ambiguous between a restructure bug and an intended design change, and the ability to tell them apart is exactly what a migration needs.

## Site structure, page by page

Nav stays as it is: Home, CV, Published Works, Working Papers, Notes, Software. Same structure, per the request.

- **Home** — hand-written. Port the bands.
- **Published Works** — a listing, `stage: published`, grouped by `kind` so Books precedes Articles as of today, ordered by year within group.
- **Working Papers** — the same listing filtered to `stage: working`. Its empty state becomes a listing property rather than an `if` in the generator.
- **Notes** — stays hand-written, and the wrong link is **fixed** (2026-07-29): "How to use the counterfactual format" had pointed at `note_Random_Assignment_Subject_To_Constraints.pdf`, the same file as the link above it, and now points at `subpages/counterfactual_format.html`.

  Two further notes in `subpages/` are **not linked but are already public**: `note_how_do_I_learn_R.pdf` and `note_how_to_write_up_an_experiment.pdf` are both tracked in the public repo and both return 200 at their URLs. Alex is not certain he wants them published, so **do not add links to them**, and note that unlinking is not the lever: on a Pages site "not linked" only lowers discovery, it does not unpublish. Withdrawing one means deleting the file from the repo, and even then the blob survives in public git history.

  A `kind: note` listing was proposed here and is **withdrawn for that reason**: generating this page from the directory would publish whatever sits in `subpages/`, which is precisely the decision Alex wants to keep making by hand. The page is four curated links and an editorial judgment about what is ready; that is not a listing, and the copy-paste error it produced is a fair price for the control. Fix errors here with a link check rather than by generating the page.
- **Software** — a listing, `kind: software`. Picks up `vayr` for free.
- **Paper page** — generated: citation, abstract, links table, coauthor links, display figure **with its gloss**, and `custom.md` appended when present. Plus, where `active_maintenance: complete`, a link to the reproducibility report, which is the thing `peer_orr_coppock_2021` proposes and currently points at nothing.

## Active maintenance on the site: a link out, with the report as the repo README

Decided 2026-07-29. A paper's project page carries a link to that paper's **GitHub repo**, and the maintenance report is that repo's **README**, rendered from the existing `.qmd` with `format: gfm`. Not a page on this site, and not a per-repo gh-pages site.

**Why the README rather than gh-pages**, on the evidence rather than by preference. All 36 reports exist and all 36 render to PDF; none renders to HTML today. They set `echo: false`, so code is never shown and there is no folding to lose. Their content is tables (11 to 17 `kable` calls each) plus figures in 29 of 36. GFM carries both: tables render natively, and figures land in a committed `<name>_files/figure-gfm/` folder, which is the same arrangement every R package uses for `README.Rmd`.

Three reasons it wins here:

- **The repo is the artifact.** Someone following that link wants the maintained code, and a README stating its reproduction status is the right landing content. A separate site inserts a layer between reader and code.
- **Zero infrastructure against 36 Pages configurations and build workflows.** `claude_control/CLAUDE.md` is explicit about CI and notification cost on public repos, and this would be 36 of them.
- **It cannot drift from the code.** A separately built site can be stale while the repo has moved; a README in the same commit cannot.

Keep the PDFs committed alongside, since GitHub renders a committed PDF natively and that gives a printable version for free without it being the primary route.

**The cost, stated plainly: the repos do not exist.** `gh repo list acoppock` has no active-maintenance repo and no folder in `active_maintenance_aec/` is a git repo, so this is not a wiring change. It needs 36 repos created, 36 `format: pdf` -> `format: gfm` conversions, one new metadata field (there is no `github_url` column today, and none should be added to the spreadsheet the restructure replaces: it belongs in `paper.yaml`), and the project-page template gaining the link. The 29 reports with figures will each bring a `figure-gfm/` folder of PNGs into their repo, which is normal and slightly cluttered.

**CORRECTED 2026-07-29 (Alex): the paper this serves is the FOLLOW-UP, not `peer_orr_coppock_2021`.** `peer_orr_coppock_2021` is the published proposal (Peer, Orr & Coppock, PS 2021). The paper that needs these repos is `active_maintenance_ai/`, Alex's single-authored 2026 follow-up reporting what happened when the proposal was actually carried out on 36 archives. Its evidence IS the 36 repos, so they are a prerequisite for it rather than a nicety.

## Sequencing

The Library's lesson, learned there at real cost, was that a vertical slice sets the agenda and a general ingester with nothing in it does not. Same here.

**Phase 0 — resolve the ambiguous copies of `projects_by_hand.xlsx`.** `works/` **stays in Dropbox and does not go under git** (Alex, 2026-07-29). Dropbox version history is therefore the recovery path, which is a real one, so the residual risk is not "no history" but **ambiguity about which file is authoritative**: `data/` currently holds `projects_by_hand.xlsx`, a Dropbox *conflicted copy* from 2026-06-23, a `_RECOVERED_OLD.bak.xlsx`, and a `.pre_cleanup_20260729`. Four files, one truth, distinguishable only by opening them. Diff the conflicted copy against the live file, keep whichever is right, and move the rest to `archive/`. Cheap, and it removes the failure mode that git was being proposed against.

**Phase 0 is DONE, both items, 2026-07-29.** The rescue found 80 site-only files rather than the 19 estimated here: all 64 card figures (works/card_figures/ did not exist) and 16 display figures. 0 site-only files remain; one conflict (`baxter-king_etal_2025_display.jpeg`) resolved in favour of the newer live copy with the older preserved as `_superseded_20250727`. The four spreadsheet copies are down to one live file plus today's dated rollback points, with both old copies archived to `archive/superseded_projects_by_hand_20260729/` after checking that neither held anything the live file lacks: all 11 of their unique keys are absent from the current `bibliography.bib`, being stale rows for ids renamed at publication. Original text follows.

**The only genuinely irreversible risk in the whole plan: rescue the site-only figures.** **14 of the 39 display figures exist ONLY in `acoppock.github.io`**, never in `works/`, because step 7 of `update_routines.txt` adds figures straight to github. **No script anywhere writes a display figure**, so not one of the 39 has a recipe and a lost one is lost permanently. This plan simultaneously describes that repo as "generated, throwaway, can be deleted and rebuilt" — both statements are true right now, which means acting on the second destroys 14 irreplaceable figures. The 5 hand-made package hexes are in the same position (no PDF source exists, since packages have no paper; their non-uniform dimensions of 988x1143, 960x960, 3124x3124 and 1276x1272 prove they were never generated by the 1000x1000 card script). **Copy all of them into `assets/` before anything is deleted, reorganized, or rebuilt.**

A related consequence worth stating rather than discovering: because `works/` is unversioned, **the generator scripts have no history**, so a change like today's brace strip in `clean_projects.R` is recoverable only through Dropbox's file-level versions. Keep changes to `code/` small and log them in `LOGFILE.md`, which is what that logfile is for.

**Phase 1 — the contract, on three hard cases.** Write `paper.yaml` by hand for exactly three papers chosen to break it: `coppock_2022` (a book, custom content, reviews, no paper PDF), `coppock_2019c` (software, no paper at all, an external project URL), and `coppock_green_2016` (an article with everything, and a finished active-maintenance rewrite). If the schema survives those three it will survive the other 57. Do not scaffold 60 folders first.

**Phase 2 — the slice, end to end.** `harvest_works()`, `check_works()`, and three rendered Quarto pages for those three papers, at their current URLs. Ugly is fine. Stop and look.

**Phase 3 — migrate the remaining 57**, mechanically, from `projects_by_hand.xlsx` plus `abstracts/` plus the bib. Mostly scriptable; the display-figure gloss is 60 sentences only Alex can write and is the real rate limit, exactly as estimand assignment is in The Library. Measure it on three before promising a date.

**Phase 4 — fold in active maintenance.** `active_maintenance_aec/<id>/` into `works/<id>/code/`, the program keeping only a thin folder of cross-paper files with a generated status table.

**Phase 5 — the emitter.** `write_paper_yaml()`, so adding a work is one command rather than the 15 manual steps in `update_routines.txt`. This is `vn_20`'s ingest protocol, and it is deliberately last: write it after 60 folders exist and the contract has stopped moving.

## Software as works, and what "more than five" costs

Decided 2026-07-29: **the R packages are works**, carried as `kind: software`, and Alex wants **more than the five currently listed, soon**. The schema decision holds and scales without change, which was the point of using a field instead of a hardcoded list. What needs planning is the three things the additional packages do not have.

Surveyed, 2026-07-29:

| | CRAN | pkgdown site | hex/logo in repo |
|---|---|---|---|
| randomizr, estimatr, fabricatr, DeclareDesign, ri2 | yes | yes | **no** |
| vayr | yes | no | **no** |
| excheckr, metaprep, estimatrTools, conjointmatchups | no | yes | **no** |
| DeclareDesignTools, attrition | no | no | **no** |
| DeclareDesignZero, fabricatrZero, estimatrZero | not yet | no | **no** |

**`vayr` is free.** It is on CRAN, it already has a bib entry with a CRAN DOI, and it is absent from the software page only because adding it meant editing a hardcoded list in a second file. Under `kind: software` the page goes from five to six the moment its folder exists. That is the whole argument for the field, demonstrated.

**1. The hexes do not exist anywhere but the website.** Not one of the 15 packages has `man/figures/logo.png`, or any image at all beyond ri2's two EGAP logos. The five hexes on the software page live only in the site repo's `card_figures/`, which is why they are on the phase-0 rescue list. So expanding to ten-plus packages is a **design deliverable of the facelift, not a data migration**: roughly nine new images to make. Worth knowing before the page is planned around having them.

**2. DOIs are out; the pkgdown site is the canonical link. RESOLVED AND SHIPPED 2026-07-29.** Alex: "no DOI for github only packages. the links should point to the pkgdown sites. In fact, all package links should point to pkgdown sites, not dois!" So the `doi` field is gone from all six `@manual` entries in `bibliography.bib`, replaced by `url` carrying the pkgdown site, and the six package pages plus the software gallery are rebuilt and live (commit `53b13f0`).

The reasoning is better than a preference. A package's canonical destination is its documentation, not a CRAN landing page. More importantly, **it is what makes a GitHub-only package listable at all**: only CRAN packages have a `10.32614/cran.package.*` DOI, so any DOI-based rule was structurally incapable of covering excheckr, metaprep, estimatrTools or conjointmatchups. A pkgdown URL covers all ten uniformly, so the rule now applies to the whole class instead of to a CRAN subset. The collision with the CV dissolved rather than needing a workaround.

Three things the change surfaced. The **CV moved with it**, since it renders from the same bib: those six entries now show their pkgdown URL, recompiled clean at 0 undefined citations, with one cosmetic wrinkle worth knowing — plainnat prefixes `url` with "URL " where `doi` rendered bare, so package lines now read slightly differently from article lines, partially reversing the single-clickable-DOI-no-URL-line goal of 2026-07-22. **ri2's project link was `http`** and is now https. **vayr had no `project_url` at all**, which was the second reason it could never appear on the software page; it is now on it, taking the page from five entries to six.

The `bdsk-url-1` fields were left alone: BibDesk's own link metadata, not printed by plainnat, and CRAN remains the correct install source.

**3. Six have no pkgdown site to link to**, and the three Zero packages are *replacements* for DeclareDesign, fabricatr and estimatr rather than additions, so listing a package beside its own rewrite would confuse readers. That is curation, not schema: they should appear on release, and `DeclareDesignTools`, `attrition` and `FEDAI` are judgment calls. The realistic near-term list is the current five plus `vayr`, `excheckr`, `metaprep`, `estimatrTools` and `conjointmatchups`, so ten.

**The listing tolerates missing pieces, and that is now built.** `make_gallery_pages.R`'s software stub gained the same per-entry card fallback the books got earlier on 2026-07-29, because no package carries a hex in its own repo and so every package added from here on arrives without one. vayr renders as a linked title today and will upgrade itself the moment a hex exists, with no code change. The pattern generalized rather than needing reinvention, which is a small sign the shape is right.

**Still open on software, and it is a naming question rather than a technical one:** the four remaining packages have no `bibliography.bib` entry and therefore no `paper_id`. All four are sole-authored Coppock and all four are 2026, so by the house convention they want `coppock_2026a` through `coppock_2026d` — and `coppock_2026` is already proposed for the `active_maintenance_ai` follow-up paper, so that is five works competing for one year's suffixes. Worth Alex deciding the ids rather than a script inventing them.

## The CV keeps rendering from `bibliography.bib`

Decided 2026-07-29: **no intermediate file.** The CV structure works and does not need the site's manifest interposed between it and the bib. So the field-ownership split stands exactly as written above: the bib owns author, title, journal, year, volume, number, pages and DOI; `paper.yaml` owns links, kind, stage, figure, gloss and rights, and never restates a bib field; they join on `bibtex_key`, and `check_works()` asserts the bijection.

The consequence to accept knowingly: **the site does not have a single hand-edited layer, it has two** — the paper folders and the bib. That is a deliberate exception rather than an oversight, because the bib has a consumer the site does not own, and the alternative (generating a bib from 60 YAML files) is the same duplication pointed the other way with a worse editor. The exception is safe only because the bijection check makes divergence loud, which is what turns a second source of truth from a hazard into a boundary.

## Decisions needed from Alex

All four opened by this plan are now closed. The open questions that remain are downstream of it:

1. **How GitHub-only packages get cited**, per point 2 above (Zenodo DOIs, a `url` field, or off the CV).
2. **Which packages appear on the software page**, per point 3 (curation, needs no schema change).

## Deliberately deferred

- Per-paper GitHub repos for active maintenance. None exist yet, so this is a forward decision with no migration pressure, and it is separable from the reorganization.
- DuckDB, an explorer, any cross-paper query interface. That is The Library's job, and this site should link to it rather than reimplement it.
- Retiring `bibliography.bib`, unless decision 3 goes the other way.
- The `Levendusky2023` key rename (convention violation, touches the CV).

## Hazards in the current tree, for whoever does the migration

Found while reading, all still true as of 2026-07-29:

- `data/projects_by_hand.xlsx` has a Dropbox **conflicted copy from 2026-06-23** plus `_RECOVERED_OLD.bak.xlsx` and a `.pre_cleanup_20260729`. Four files, one truth, distinguishable only by opening them. Phase 0 exists because of this. `works/` stays in Dropbox by decision, so version history is the recovery path and the job is removing the ambiguity, not adding a VCS.
- **13 of the 38 display figures the spreadsheet names exist only in the site tree**, because step 7 of `update_routines.txt` adds figures straight to github. The site is the de facto source for figures, so a naive migration of `works/display_figures/` loses a third of them.
- `abstracts/` holds `blair_cooper_coppock_humphreys_2021.txt`, a key matching no current paper.
- `bibliography/` keeps LaTeX build artifacts (`.aux`, `.bbl`, `.fls`, `.fdb_latexmk`) beside the source.
- `include_lessons_nav.html` is an orphan fragment from the repo's initial commit, included by **no page**, containing 15 dangling `lesson-N.html` links. Harmless, but it is what a broadened link check finds: each time the sweep widens it turns something up, which argues for widening it once more rather than assuming it is complete.
- `code/` mixes the live generator with exploratory files (`pratice_bipartite_graph.R`, `pratice_bipartite_graph_V2.R`, `second_try.R`). Quarantine, do not delete.
- `make_card_images.R`'s paper branch runs at a hardcoded `i <- 31` and silently writes whatever card that index happens to be, which produced an unrequested `coppock_green_porter_2026_preprint_card.png` on 2026-07-29.
