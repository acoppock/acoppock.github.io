# Phase 2 vertical slice: render the paper folders as Quarto pages at their
# current flat URLs. Ugly is fine. The point is to find out what the contract
# cannot express, not to look finished.
#
# Software deliberately gets no page (Alex, 2026-07-29). The Software listing
# links straight out to the pkgdown site, so this script renders the listing
# from `kind: software` rather than from a hardcoded set of calls.

source("code/harvest_works.R")
source("code/build_project_page.R")

# The built site does not live in Dropbox (Alex, 2026-07-31): it belongs only
# in the git repo. The build directory sits beside the repo, is gitignored, and
# is regenerable from works/ at any time, so nothing of value lives here.
slice_dir <- "/Users/alexandercoppock/git_projects/acoppock.github.io/_build"

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
        '---\ntitle: ""\npagetitle: "Moved"\n---\n\n',
        '<div class="workHeader"><div class="workBody">\n',
        '<h1 class="workTitle">This page has moved</h1>\n',
        '<div class="workAbstract">The corrigendum and the article it corrects are one entry. ',
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
      '---\ntitle: ""\npagetitle: "Software"\n---\n\n',
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

  # Every non-URL link target: papers, appendices, and the book's extra PDFs.
  # Link targets AND published_files: the second are live citable URLs that no
  # page links, so copying only what is linked loses them.
  local_files <- bind_rows(
    harvest$links |> filter(!is_url) |> transmute(work_id, file = target),
    harvest$published_files |> transmute(work_id, file)
  ) |> distinct()
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
  bib_keys_to_publish <- c(
    harvest$works |> filter(kind != "software") |> pull(bibtex_key),
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

  # Site-level files: the CV the nav links, the Notes the Notes page links, and
  # everything under subpages/. None belongs to a work, so none is reachable
  # through the works tables, and publishing only work-owned files would leave
  # the nav pointing at a 404.
  file.copy(file.path(root, "curriculum_vitae", "coppock_cv.pdf"), out, overwrite = TRUE)
  # NEVER blanket-copy documents/. It holds Alex's own copy of the watermarked
  # book PDF, which was publicly retrievable until it was purged from the site
  # repo's history in July 2026 at real cost. A copy-everything rule put it
  # straight back into the build on 2026-07-31 and it reached a branch before
  # being caught. Excluded by name, and anything else that should not be
  # published goes on this list rather than being remembered.
  never_publish <- c("Coppock_9780226821825_Watermarked_AEC.pdf")
  site_docs <- list.files(file.path(root, "documents"), full.names = TRUE) |>
    discard(~ basename(.x) %in% never_publish)
  file.copy(site_docs, out, overwrite = TRUE)
  dir.create(file.path(out, "subpages"), showWarnings = FALSE)
  file.copy(list.files(file.path(root, "subpages"), full.names = TRUE),
            file.path(out, "subpages"), overwrite = TRUE)

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
