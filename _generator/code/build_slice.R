# Phase 2 vertical slice: render the paper folders as Quarto pages at their
# current flat URLs. Ugly is fine. The point is to find out what the contract
# cannot express, not to look finished.
#
# Software deliberately gets no page (Alex, 2026-07-29). The Software listing
# links straight out to the pkgdown site, so this script renders the listing
# from `kind: software` rather than from a hardcoded set of calls.

source("site/code/harvest_works.R")
source("site/code/build_project_page.R")

# The built site does not live in Dropbox (Alex, 2026-07-31): it belongs only
# in the git repo. The build directory sits beside the repo, is gitignored, and
# is regenerable from works/ at any time, so nothing of value lives here.
slice_dir <- "/Users/alexandercoppock/git_projects/acoppock_site_build"

link_labels <- c(
  paper = "Link to paper",
  appendix = "Link to appendix",
  journal = "Journal site",
  project = "Project site",
  replication_archive = "Replication archive",
  preanalysis_plan = "Preanalysis plan"
)

# Ported from clean_projects.R per notes/port_audit_20260730.md. The first
# author is inverted, the rest stay natural, and three or more take an Oxford
# comma. Accents and braces are already gone: read_bib() resolved them.
format_authors <- function(people) {
  if (is.null(people) || !nrow(people)) return(NA_character_)
  natural <- people$full_name
  inverted <- if (nzchar(people$first_name[1])) {
    str_c(people$last_name[1], ", ", people$first_name[1])
  } else {
    people$last_name[1]
  }
  out <- c(inverted, natural[-1])
  n <- length(out)
  if (n == 1) return(out)
  if (n == 2) return(str_flatten(out, " and "))
  str_c(str_flatten(out[-n], ", "), ", and ", out[n])
}

# `with_title = FALSE` for the project page, where the <h1> beside the card
# already carries the title and repeating it in bold two lines below is the
# clutter Alex saw. Galleries keep the title, because there the citation is the
# only text an item has.
format_citation <- function(entry, with_title = TRUE) {
  authors <- format_authors(entry$author_parsed[[1]])

  # The venue fallback chain, ported whole. Handling only journal and publisher
  # left a chapter, a dissertation and every package with no venue at all, which
  # is how the dissertation's citation once read "... Response to Information. NA."
  venue <- coalesce(entry$journal, entry$note, entry$booktitle,
                    entry$publisher, entry$type, entry$school)

  # The author list already ends in a period when the last name is an initial;
  # appending ". " unconditionally produced "Green.. 2016".
  bits <- if (with_title) {
    str_c(str_remove(authors, "\\.$"), ". ", entry$year, ". <b>", entry$title, "</b>.")
  } else {
    str_c(str_remove(authors, "\\.$"), ". ", entry$year, ".")
  }

  if (!is.na(venue)) {
    vol <- if (!is.na(entry$volume)) str_c(" ", entry$volume) else ""
    num <- if (!is.na(entry$number)) str_c("(", entry$number, ")") else ""
    # Any run of hyphens, not just a literal "--": read_bib already turns the
    # BibTeX form into an en dash, and this catches whatever else appears. A real
    # character rather than the &ndash; entity the old generator emits, so the
    # two paths agree; browsers render them identically.
    pgs <- if (!is.na(entry$pages)) str_c(": ", str_replace_all(entry$pages, "-+", "–")) else ""
    series <- if (is.na(entry$journal) && !is.na(entry$series)) str_c(", ", entry$series) else ""
    bits <- str_c(bits, " ", venue, series, vol, num, pgs, ".")
  }

  if (!is.na(entry$doi)) {
    bits <- str_c(bits, " <a href='https://doi.org/", entry$doi,
                  "' target='_blank'>doi:", entry$doi, "</a>")
  }
  bits
}

build_links <- function(id, harvest, coauthor_file) {
  rows <- harvest$links |> filter(work_id == id)
  labelled <- rows |>
    mutate(label = if_else(slot == "extra", label, unname(link_labels[slot])))

  coauthor_rows <- harvest$coauthors |>
    filter(work_id == id) |>
    left_join(coauthor_file, by = "slug") |>
    transmute(label = str_c(full_name, "'s website"), target = website)

  bind_rows(
    labelled |> select(label, target),
    coauthor_rows,
    tibble(label = "Bibtex citation", target = str_c(id, ".txt"))
  ) |>
    glue_data(" - <a href='{target}' target='_blank'>{label}</a>") |>
    str_flatten("\n")
}

figure_block <- function(asset, id) {
  if (nrow(asset) == 0 || is.na(asset$file)) return("")
  dir <- if (asset$role == "cover") "book_covers" else "display_figures"
  out <- str_c('<center><img src="', dir, "/", asset$file,
               '" alt="', id, '" width="600"></center>')
  if (!is.na(asset$gloss)) {
    out <- str_c(out, "\n\n", str_squish(asset$gloss), "\n")
  }
  out
}

build_slice <- function(root = ".", show_figure = TRUE) {
  harvest <- harvest_works(root)
  coauthor_file <- read_excel(file.path(root, "data", "coauthors_by_hand.xlsx"))

  dir.create(slice_dir, showWarnings = FALSE)
  for (d in c("display_figures", "book_covers", "card_figures", "page1")) {
    dir.create(file.path(slice_dir, d), showWarnings = FALSE)
  }

  # Sweep the page sources this function owns before writing them.
  #
  # Nothing here ever deleted a .qmd, so a work that is renamed or removed left
  # its page behind and Quarto re-rendered it forever. The 2026-08-03 rename
  # made it visible: `coppock_2021b.qmd` and `coppock_2025a.qmd` survived and
  # rendered pages pointing at PDFs that no longer existed. This is the same
  # shape as the five leaks already recorded (css/, js/, subpages/, note thumbs,
  # _generator/), and the same rule applies: a directory the build populates
  # must be emptied before it is filled, or its contents are the union of every
  # state the build has ever been in.
  #
  # `_quarto.yml`, the stylesheets and the asset directories are written or
  # copied separately below, so only the generated page sources are swept.
  unlink(list.files(slice_dir, "\\.qmd$", full.names = TRUE))
  unlink(list.files(slice_dir, "_files$", full.names = TRUE), recursive = TRUE)

  write_lines(c(
    "project:",
    "  type: default",
    "  output-dir: _site",
    "format:",
    "  html:",
    "    theme: cosmo",
    "    toc: false",
    "    css: slice.css"
  ), file.path(slice_dir, "_quarto.yml"))

  write_lines(c(
    "/* Ported look, not the new brand: the restructure is verified by pages",
    "   that look UNCHANGED, and the brand lands as its own separate pass. */",
    "body { max-width: 900px; margin: 0 auto; }"
  ), file.path(slice_dir, "slice.css"))

  # NOT `pages`: the bib carries a `pages` FIELD, and inside a data-masked
  # filter() that column shadows a local variable of the same name.
  #
  # `stage: staged` is what the `no_page_yet` list used to say, and software
  # gets no page by decision. Both are now fields on the work rather than
  # membership in a list kept somewhere else.
  page_works <- harvest$works |>
    filter(kind != "software", stage == "published")

  for (i in seq_len(nrow(page_works))) {
    id <- page_works$work_id[i]
    write_lines(build_project_page(id, harvest, coauthor_file, root, show_figure = show_figure),
                file.path(slice_dir, str_c(id, ".qmd")))

    # The page leads with the card, so cards travel with the pages as well as
    # with the gallery.
    for (a in (harvest$assets |> filter(work_id == id, role %in% c("display", "cover", "card", "page1"), !is.na(file)))$file) {
      row <- harvest$assets |> filter(work_id == id, file == a) |> slice(1)
      dest_dir <- switch(row$role, display = "display_figures", cover = "book_covers",
                         card = "card_figures", page1 = "page1")
      src <- file.path(works_dir(root), id,
                       if (row$role %in% c("card", "page1")) "assets" else "original_materials", a)
      if (file.exists(src)) file.copy(src, file.path(slice_dir, dest_dir, a), overwrite = TRUE)
    }
  }

  # Stub pages for superseded ids. The URL policy does not distinguish between
  # a URL lost to deletion and one lost to a merge, so the id keeps its page and
  # the page sends the reader to the work that absorbed it.
  if (nrow(harvest$supersedes)) {
    for (i in seq_len(nrow(harvest$supersedes))) {
      old <- harvest$supersedes$superseded[i]
      new <- harvest$supersedes$work_id[i]
      entry <- harvest$bib |> filter(bibtex_key == new)
      write_lines(str_c(
        '---\ntitle: ""\npagetitle: "Moved"\n',
        og_front_matter(str_c(entry$title, " | Alexander Coppock"),
                        str_c("This page has moved. The work is now published as ",
                              entry$title, "."),
                        "images/front_page.png", str_c(old, ".html")),
        '---\n\n',
        '<div class="workProse">\n',
        '<h1>This page has moved</h1>\n',
        '<div>The corrigendum and the article it corrects are one entry. ',
        'See <a href="', new, '.html">', entry$title, '</a>.</div>\n',
        '</div></div>\n'
      ), file.path(slice_dir, str_c(old, ".qmd")))
    }
  }

  # The Software listing, generated from `kind: software`. Today this is five
  # hardcoded make_software_entry() calls in software.rmd, which is why vayr
  # was invisible for so long.
  software <- harvest$works |> filter(kind == "software")
  if (nrow(software)) {
    # The same card-and-description pattern as the papers gallery (Alex,
    # 2026-07-31). A single wrapper class carries the software-specific styling,
    # because pandoc keeps only the first class of a raw HTML div and a second
    # class on the item would be silently dropped.
    cites <- harvest$bib |>
      mutate(citation = map_chr(seq_len(n()), ~ format_citation(harvest$bib[.x, ]))) |>
      select(bibtex_key, citation, title)

    tiles <- software |>
      left_join(harvest$links |> filter(slot == "project"), by = "work_id") |>
      left_join(cites, by = "bibtex_key") |>
      left_join(harvest$assets |> filter(role == "card") |> select(work_id, card = file),
                by = "work_id") |>
      mutate(
        # A package citation opens with "name: what it does", and the name is
        # the part a reader scans for, so it is bolded on its own rather than
        # the whole title being bold.
        citation = str_replace(citation, "<b>([^:<]+): ", "<b>\\1</b>: "),
        citation = str_replace(citation, "</b>\\.", "."),
        card_src = map2_chr(work_id, card, function(id, f) {
          if (is.na(f)) return(NA_character_)
          hit <- c(file.path(works_dir(root), id, "assets", f),
                   file.path(works_dir(root), id, "original_materials", f)) |>
            keep(file.exists)
          if (length(hit)) hit[1] else NA_character_
        }),
        has_card = !is.na(card_src),
        item = if_else(
          has_card,
          str_c("<div class='galleryItem'>\n",
                "<a href='", target, "'> <img class='galleryItemImage' src='card_figures/", card, "'/> </a>\n",
                "<div class='galleryItemDescription'> ", citation, " </div>\n</div>"),
          str_c("<div class='galleryItem'>\n",
                "<a class='galleryItemLabel' href='", target, "'>", work_id, "</a>\n",
                "<div class='galleryItemDescription'> ", citation, " </div>\n</div>")
        )
      )

    write_lines(str_c(
      '---\ntitle: ""\npagetitle: "Software"\n',
      og_front_matter("Software | Alexander Coppock",
                      "R packages by Alexander Coppock: randomizr, ri2, estimatr, fabricatr, DeclareDesign, vayr, metaprep, excheckr, estimatrTools and conjointmatchups.",
                      "images/front_page.png", "software.html"),
      '---\n\n',
      '<div class="softwareGallery">\n<div class="galleryItems">\n',
      str_flatten(tiles$item, "\n"),
      '\n</div>\n</div>\n'
    ), file.path(slice_dir, "software.qmd"))

    dir.create(file.path(slice_dir, "card_figures"), showWarnings = FALSE)
    walk2(tiles$card_src, tiles$card, function(src, f) {
      if (!is.na(src)) file.copy(src, file.path(slice_dir, "card_figures", f), overwrite = TRUE)
    })
  }

  invisible(harvest)
}

# Everything a page links that is not a page. Quarto renders the .qmd files; the
# PDFs and the bibtex .txt files are published beside them at the root, which is
# the "publish flat whatever the source looks like" requirement. Run AFTER
# `quarto render`, since Quarto clears its output directory.
publish_assets <- function(root = ".") {
  harvest <- harvest_works(root)
  out <- file.path(slice_dir, "_site")
  stopifnot(dir.exists(out))

  # `quarto render` does NOT clear its output directory, so anything that stops
  # being generated stays published. Found when a bibtex file for software kept
  # reappearing after the rule that emits it was removed. That matters more than
  # tidiness here: 12 package URLs and 22 working-paper URLs were retired ON
  # PURPOSE, and a build that never deletes would quietly restore them. Only the
  # flat files this function owns are swept; Quarto's own output is left alone.
  owned <- list.files(out, pattern = "\\.(pdf|txt)$", full.names = TRUE)
  if (length(owned)) file.remove(owned)

  # The generator, copied onto the site so the code that produces it has a
  # history in the same repository. It was a one-time hand copy and had already
  # drifted from works/code in four files by 2026-07-31, so it is build output
  # now. The script list is explicit rather than a glob: a retired script must
  # not reappear here just because it is still sitting in the directory.
  # Mirrored, not copied into. This is the fifth place today where copying into
  # a directory left a retired file published: css/, js/, subpages/, the notes
  # thumbs, and here, where a deleted README.md and port_audit went on being
  # served. Anything the build owns wholesale gets emptied first.
  gen <- file.path(out, "_generator")
  unlink(gen, recursive = TRUE)
  dir.create(file.path(gen, "code"), recursive = TRUE, showWarnings = FALSE)
  pipeline_scripts <- c("build_site.R", "harvest_works.R", "read_bib.R", "build_slice.R",
                        "build_project_page.R", "build_galleries.R",
                        "build_site_chrome.R", "check_links.R",
                        "make_bib_files.R", "make_card_images.R",
                        "make_page1_thumbnails.R")
  file.copy(file.path(root, "site", "code", pipeline_scripts), file.path(gen, "code"),
            overwrite = TRUE)
  file.copy("/Users/alexandercoppock/Dropbox/claude_control/tools/brand.scss", gen,
            overwrite = TRUE)
  # update_routines.txt replaces the old README.md, which described the
  # five-call build retired by build_site.R and still advertised the
  # `never_publish` blocklist that the allowlist replaced. Two documents that
  # disagree are worse than one.
  for (f in c("update_routines.txt", "retired_urls.txt")) {
    src <- file.path(root, "notes", f)
    if (file.exists(src)) file.copy(src, gen, overwrite = TRUE)
  }

  # A sitemap, listing what is actually in the output rather than what the
  # catalog says should be. Redirect stubs are excluded: pointing a crawler at
  # a page whose only content is "this has moved" competes with the page it
  # moved to.
  moved <- str_c(harvest$supersedes$superseded, ".html")
  pages <- list.files(out, pattern = "\\.html$") |>
    setdiff(c(moved, "404.html")) |>
    sort()
  loc <- if_else(pages == "index.html", "", pages)
  write_lines(c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    str_c("  <url><loc>", SITE_URL, "/", loc, "</loc></url>"),
    "</urlset>"
  ), file.path(out, "sitemap.xml"))

  write_lines(c("User-agent: *", "Allow: /", "",
                str_c("Sitemap: ", SITE_URL, "/sitemap.xml")),
              file.path(out, "robots.txt"))

  # The custom domain. It lived only at the repo root, which meant the built
  # tree was not a complete description of what should be published and an
  # rsync --delete would have taken the domain down. Emitted here so the build
  # output is authoritative and the sync can safely delete what it does not
  # produce.
  write_lines("alexandercoppock.com", file.path(out, "CNAME"))

  # Without this Pages runs Jekyll, which skips every path beginning with an
  # underscore. _generator/ would silently not be served.
  write_lines("", file.path(out, ".nojekyll"))

  # Every non-URL link target: papers, appendices, and the book's extra PDFs.
  # Link targets AND published_files: the second are live citable URLs that no
  # page links, so copying only what is linked loses them.
  # Dormant works publish nothing at all. Excluding them from the bibtex rule
  # was not enough: link targets are copied here too, so coppock_2017b.pdf and
  # its appendix were still being served for a work with no page.
  live <- harvest$works |> filter(stage != "dormant") |> pull(work_id)
  local_files <- bind_rows(
    harvest$links |> filter(!is_url) |> transmute(work_id, file = target),
    harvest$published_files |> transmute(work_id, file)
  ) |>
    filter(work_id %in% live) |>
    distinct()
  copied_docs <- local_files |>
    mutate(src = file.path(works_dir(root), work_id, "original_materials", file)) |>
    filter(file.exists(src)) |>
    mutate(ok = file.copy(src, file.path(out, file), overwrite = TRUE)) |>
    pull(ok)

  # One bibtex file per paper, from make_bib_files.R's output. That script parses
  # the bib with its own reader and is independent of this layer, so it is run
  # rather than reimplemented.
  # Only papers that get a page get a bibtex file. Software does not: its .txt
  # was linked from nowhere once the gallery started going straight out to the
  # pkgdown site, which already serves a citation page with a BibTeX block, so
  # the six package .txt URLs were retired deliberately on 2026-07-29. Emitting
  # one here would quietly resurrect a URL the snapshot records as removed.
  bib_dir <- file.path(root, "bibliography", "separate_bib_files")
  # Superseded ids keep their bibtex file too: the entry still exists in the bib
  # (the CV cites it) and the .txt URL is live, so a merge must not silently
  # retire it any more than it retires the page.
  # `stage != "dormant"` as well as `kind != "software"` (Alex, 2026-07-31):
  # a dormant work is to leave no record on the site, and a bibtex stub is a
  # record. coppock_2015.txt was in the pre-migration snapshot but 404s on the
  # live site, so retiring it takes nothing away from anybody.
  bib_keys_to_publish <- c(
    harvest$works |> filter(kind != "software", stage != "dormant") |> pull(bibtex_key),
    harvest$supersedes$superseded
  ) |> unique()

  copied_bib <- bib_keys_to_publish |>
    keep(~ file.exists(file.path(bib_dir, str_c(.x, ".txt")))) |>
    map_lgl(~ file.copy(file.path(bib_dir, str_c(.x, ".txt")),
                        file.path(out, str_c(.x, ".txt")), overwrite = TRUE))

  # Quarto does not reliably re-copy project resources: measured, _site kept a
  # 7920-byte project_page.css while the source was 9359, so a whole block of
  # style changes was invisible on every page and looked like the CSS "not
  # working". Copied explicitly here, which is the only way to be sure the
  # served stylesheet is the one on disk.
  for (f in c("project_page.css", "slice.css")) {
    src <- file.path(slice_dir, f)
    if (file.exists(src)) file.copy(src, file.path(out, f), overwrite = TRUE)
  }

  # css/ and js/ are MIRRORED, not copied into. Emptying them in the build
  # directory was not enough: Quarto copies project resources into _site and
  # never clears _site, so js/rmarkdown.js survived there after being retired
  # and the sync carried it to the branch. It was still being served hours
  # after it was deleted. Found 2026-08-01 by listing the branch rather than
  # trusting that the deletion had taken.
  # `note_thumbs` joined the list on 2026-08-03, for exactly the reason the
  # comment above describes: sweeping it in the build directory was not enough,
  # because Quarto had already copied the stale thumbnail into _site. A renamed
  # note left `coppock_cooper_fultz_2015_cheatsheet.png` there and it was still
  # being published months later. Measured rather than assumed: comparing each
  # build-owned directory against its _site counterpart showed note_thumbs was
  # the only one with an extra file (8 against 9).
  for (d in c("css", "js", "note_thumbs")) {
    unlink(file.path(out, d), recursive = TRUE)
    dir.create(file.path(out, d), showWarnings = FALSE)
    file.copy(list.files(file.path(slice_dir, d), full.names = TRUE),
              file.path(out, d), overwrite = TRUE)
  }

  # Site-level files: the CV the nav links, the Notes the Notes page links, and
  # everything under subpages/. None belongs to a work, so none is reachable
  # through the works tables, and publishing only work-owned files would leave
  # the nav pointing at a 404.
  file.copy(file.path(root, "curriculum_vitae", "coppock_cv.pdf"), out, overwrite = TRUE)

  # Notes. One folder, files dumped in, thumbnails in a subfolder (Alex,
  # 2026-07-31). Deliberately looser than a work: a note gets no folder of its
  # own and no work.yaml, because the apparatus buys nothing when the only
  # metadata is a title and a coauthor. Those live in the notes table in
  # build_site_chrome.R, which stays hand-curated.
  #
  # This replaces site_documents/ and subpages/, which had both drifted into
  # being about notes and nothing else.
  note_files <- list.files(file.path(root, "site", "notes"), full.names = TRUE) |>
    discard(~ basename(.x) == "thumbs")
  file.copy(note_files, out, overwrite = TRUE)

  # subpages/ is gone entirely (Alex, 2026-07-31): the two notes that lived
  # under that prefix are canonical at the root and the old addresses are
  # retired rather than mirrored.
  unlink(file.path(out, "subpages"), recursive = TRUE)

  # There is deliberately no alias mechanism here. One was added on 2026-08-03
  # to keep `coppock_cooper_fultz_2015_cheatsheet.pdf` resolving beside
  # `randomizr_cheatsheet.pdf`, and Alex removed it the same day: he wants ONE
  # copy of the cheatsheet, at the better name. A table with no rows in it is
  # speculation, so it is gone rather than left empty.

  # The migration is not done until a rebuilt site contains every URL that the
  # pre-migration snapshot recorded. Now that the site is complete, check EVERY
  # snapshot URL rather than only the ones a work owns.
  snapshot <- read_lines(file.path(root, "notes", "published_urls_20260729.txt")) |>
    discard(~ str_starts(.x, "#") | .x == "")

  # Subtract the URLs removed on purpose. Without this the check can never go
  # green, and a check that is always red is one nobody reads.
  retired_path <- file.path(root, "notes", "retired_urls.txt")
  retired <- if (file.exists(retired_path)) {
    read_lines(retired_path) |> discard(~ str_starts(.x, "#") | .x == "")
  } else character()
  snapshot <- setdiff(snapshot, retired)
  # A snapshot URL belongs to a paper when it is "<id>.<ext>" or "<id>_<something>",
  # which is what catches the appendix. Matching on a truncated prefix silently
  # skipped coppock_green_2016_appendix.pdf.
  mine <- snapshot
  present <- mine |> map_lgl(~ file.exists(file.path(out, .x)))

  list(
    documents = sum(copied_docs), bibtex = sum(copied_bib),
    urls_expected = length(mine), urls_present = sum(present),
    missing = mine[!present]
  )
}
