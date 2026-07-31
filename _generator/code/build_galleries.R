# The gallery pages, generated from `kind` and `stage`.
#
# This retires make_gallery_pages.R, which held a hand-ordered run of 38
# make_entry() calls plus five hardcoded section blocks. Section membership,
# ordering and the empty state are all read off the works now, so adding a work
# is adding a folder.

source("code/harvest_works.R")

# Section order on the page, and which kind fills each. Books before Articles is
# the order the site adopted on 2026-07-29.
sections <- tribble(
  ~title,                          ~kind,
  "Books",                         "book",
  "Articles",                      "article",
  "Book reviews",                  "review",
  "Crowdsourced collaborations",   "crowdsourced",
  "Dissertation",                  "dissertation"
)

gallery_item <- function(work_id, citation, title, card_exists) {
  # The card fallback: no card file means a linked title rather than a broken
  # image. Keyed on the file, not on a list of who is expected to have one.
  if (card_exists) {
    str_c(
      '<div class="galleryItem">\n',
      '  <a href="', work_id, '.html"> <img class="galleryItemImage" src="card_figures/',
      work_id, '_card.png"/> </a>\n',
      '  <div class="galleryItemDescription"> ', citation, ' </div>\n',
      '  </div>'
    )
  } else {
    str_c(
      '<div class="galleryItem">\n',
      '  <a class="galleryItemLabel" href="', work_id, '.html">', title, '</a>\n',
      '  <div class="galleryItemDescription"> ', citation, ' </div>\n',
      '  </div>'
    )
  }
}

build_galleries <- function(root = ".") {
  harvest <- harvest_works(root)

  # One citation per bib entry, built once and joined. Computing them row-wise
  # inside a mutate looked equivalent and was not: the index resolved against
  # the bib rather than against the works, so every gallery item carried some
  # other work's citation.
  citations <- harvest$bib |>
    mutate(citation = map_chr(seq_len(n()), ~ format_citation(harvest$bib[.x, ]))) |>
    select(bibtex_key, citation)

  published <- harvest$works |>
    filter(stage == "published", kind != "software") |>
    left_join(harvest$bib |> select(bibtex_key, title, year), by = "bibtex_key") |>
    left_join(citations, by = "bibtex_key") |>
    mutate(
      card_file = file.path(works_dir(root), work_id, "assets", str_c(work_id, "_card.png")),
      card_exists = file.exists(card_file)
    )

  # Reverse chronological within a section, which is what the hand-ordered list
  # encoded and what the site shows today.
  blocks <- sections |>
    pmap_chr(function(title, kind) {
      items <- published |>
        filter(.data$kind == .env$kind) |>
        arrange(desc(as.numeric(year)), work_id)
      if (!nrow(items)) return("")
      str_c(
        '<div class="gallerySectionTitle">', title, '</div>\n<div class="galleryItems">\n',
        str_flatten(pmap_chr(list(items$work_id, items$citation, items$title, items$card_exists),
                             gallery_item), "\n"),
        '\n</div>'
      )
    })

  # The gallery is its cards. They live in each work's assets/ folder now, so
  # the page references resolve only if they are copied out; without this every
  # one of the 43 images is broken and the page is nothing but captions.
  dir.create(file.path(slice_dir, "card_figures"), showWarnings = FALSE)
  published |>
    filter(card_exists) |>
    pull(card_file) |>
    walk(~ file.copy(.x, file.path(slice_dir, "card_figures", basename(.x)),
                     overwrite = TRUE))

  page <- str_c(
    '---\ntitle: ""\npagetitle: "Published Works"\n---\n\n',
    '<div class="band full">\n<div class="bandContent gallerySection">\n',
    str_flatten(blocks[nzchar(blocks)], "\n\n"),
    '\n</div>\n</div>\n'
  )
  write_lines(page, file.path(slice_dir, "published_papers.qmd"))

  # Working Papers: the same listing filtered to stage == "working". Its empty
  # state is a property of the listing rather than an `if` in a generator, which
  # is the whole point. Alex directed on 2026-07-29 that no working paper appear
  # on the site, so `staged` deliberately does NOT feed this page.
  working <- harvest$works |> filter(stage == "working")
  notice <- if (!nrow(working)) {
    "There are no working papers posted at the moment."
  } else ""
  write_lines(
    str_c('---\ntitle: ""\npagetitle: "Working Papers"\n---\n\n', notice, "\n"),
    file.path(slice_dir, "working_papers.qmd")
  )

  counts <- published |> count(kind)
  list(sections = counts, n_published = nrow(published), n_working = nrow(working))
}

# The home page bibliography (Alex, 2026-07-31): the same works the galleries
# show, as CV-style text below the fold. It is an alternative way in, not a
# replacement, so the galleries are untouched.
#
# The structure is the CV's own. Sections in the CV's order, and within a
# section, year subheadings where the section is long enough to need them and
# the year folded into the entry where it is not. That is why `year_headings`
# is a column rather than a rule inferred from the row count: which sections
# get subheadings is a judgement about how the page reads, so it is written
# down where it can be seen and changed.
bib_sections <- tribble(
  ~title,                          ~kind,           ~year_headings,
  "Books",                         "book",          FALSE,
  "Articles",                      "article",       TRUE,
  "Software",                      "software",      FALSE,
  "Book reviews",                  "review",        FALSE,
  "Crowdsourced collaborations",   "crowdsourced",  FALSE,
  "Dissertation",                  "dissertation",  FALSE
)

bibliography_entry <- function(it, show_year) {
  authors <- format_authors(it$author_parsed[[1]])

  # Software has no PDF and no project page, so its title goes to its pkgdown
  # site. Everything else prefers the PDF and falls back to its project page.
  title_href <- coalesce(it$paper_url, it$project_url, str_c(it$work_id, ".html"))

  out <- str_c(
    '<div class="bibEntry">',
    str_remove(authors, "\\.$"), '. ',
    '<a class="bibTitle" href="', title_href, '">', it$title, '</a>.'
  )

  venue <- coalesce(it$journal, it$booktitle, it$publisher, it$type, it$school, it$note)
  if (!is.na(venue)) {
    # "R package version 1.0.0" is a note, not a venue, so it is not set in the
    # italic a journal name gets.
    is_venue <- !is.na(coalesce(it$journal, it$booktitle, it$publisher, it$type, it$school))
    vol <- if (!is.na(it$volume)) str_c(" ", it$volume) else ""
    num <- if (!is.na(it$number)) str_c("(", it$number, ")") else ""
    pgs <- if (!is.na(it$pages)) str_c(": ", str_replace_all(it$pages, "-+", "–")) else ""
    series <- if (is.na(it$journal) && !is.na(it$series)) str_c(", ", it$series) else ""
    body <- if (is_venue) str_c('<i>', venue, '</i>') else venue
    out <- str_c(out, ' ', body, series, vol, num, pgs)
    # Under a year subheading the year is already stated; without one it goes
    # here, which is where the CV puts it.
    out <- str_c(out, if (show_year) str_c(", ", it$year, ".") else ".")
  } else if (show_year) {
    out <- str_c(out, " ", it$year, ".")
  }

  if (!is.na(it$journal_url)) {
    is_doi <- str_detect(it$journal_url, "doi\\.org/")
    label <- if (is_doi) {
      str_c("doi:", str_remove(it$journal_url, "^https?://(dx\\.)?doi\\.org/"))
    } else {
      # A publisher page rather than a DOI. The bare URL ran to three lines, so
      # the host stands in for it.
      str_remove(str_extract(it$journal_url, "^https?://[^/]+"), "^https?://(www\\.)?")
    }
    out <- str_c(out, ' <a class="bibDoi" href="', it$journal_url, '" target="_blank">',
                 label, '</a>')
  }

  # Software gets no marker: build_slice gives it no project page to point at.
  if (it$kind != "software") {
    out <- str_c(out, ' <a class="bibMore" href="', it$work_id,
                 '.html" title="Project page">&#9656;</a>')
  }
  str_c(out, '</div>')
}

build_bibliography <- function(root = ".") {
  harvest <- harvest_works(root)

  works <- harvest$works |>
    filter(stage == "published") |>
    left_join(harvest$bib, by = "bibtex_key") |>
    left_join(harvest$links |> filter(slot == "paper") |> select(work_id, paper_url = target),
              by = "work_id") |>
    left_join(harvest$links |> filter(slot == "journal") |> select(work_id, journal_url = target),
              by = "work_id") |>
    left_join(harvest$links |> filter(slot == "project") |> select(work_id, project_url = target),
              by = "work_id")

  blocks <- bib_sections |>
    pmap_chr(function(title, kind, year_headings) {
      items <- works |>
        filter(.data$kind == .env$kind) |>
        arrange(desc(as.numeric(year)), work_id)
      if (!nrow(items)) return("")

      entries <- if (year_headings) {
        # Split by year in the order the arrange produced. group_by/group_map
        # would re-sort the groups ascending and put 2013 at the top.
        unique(items$year) |>
          map_chr(function(y) {
            rows <- items |> filter(year == y)
            str_c('<div class="bibYear">', y, '</div>\n',
                  str_flatten(map_chr(seq_len(nrow(rows)),
                                      ~ bibliography_entry(rows[.x, ], show_year = FALSE)), "\n"))
          }) |>
          str_flatten("\n")
      } else {
        str_flatten(map_chr(seq_len(nrow(items)),
                            ~ bibliography_entry(items[.x, ], show_year = TRUE)), "\n")
      }

      str_c('<div class="bibSection">', title, '</div>\n', entries)
    })

  str_c('<div class="bibliography">\n', str_flatten(discard(blocks, ~ .x == ""), "\n"), '\n</div>')
}
