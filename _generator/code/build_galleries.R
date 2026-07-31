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
