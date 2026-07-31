# Phase 3: write metadata/paper.yaml for every work.
#
# This script is the transposition the plan describes: it reads the five
# hardcoded lists ONCE, out of the generator scripts that hold them, and writes
# what they encode into the paper folders as `kind` and `stage`. After it runs,
# the lists have no readers left.
#
# Run once. It never overwrites an existing paper.yaml, so the three written by
# hand in Phase 1 stay as they are.

source("code/harvest_works.R")

gallery_path <- "code/make_gallery_pages.R"
pages_path <- "code/make_project_pages.R"

# Section membership, read out of the gallery script. A key's section is the
# last gallerySectionTitle seen above its make_entry() call.
read_sections <- function(path) {
  lines <- read_lines(path)
  section <- NA_character_
  out <- list()
  for (ln in lines) {
    title <- str_match(ln, "gallerySectionTitle\">([^<]+)<")[, 2]
    if (!is.na(title)) section <- title
    key <- str_match(ln, "^make_entry\\(\"([^\"]+)\"\\)")[, 2]
    if (!is.na(key)) out[[key]] <- section
  }
  tibble(bibtex_key = names(out), section = unlist(out))
}

# The three exclusion lists, evaluated from their own source rather than
# retyped, so this cannot drift from what the site actually does today.
read_vector <- function(path, name) {
  src <- read_file(path)
  block <- str_match(src, str_c(name, "\\s*<-\\s*(c\\((?:[^()]|\\([^()]*\\))*\\))"))[, 2]
  if (is.na(block)) character() else eval(parse(text = block))
}

sections <- read_sections(gallery_path)
no_page_yet <- read_vector(pages_path, "no_page_yet")
custom_pages <- read_vector(pages_path, "custom_pages")
not_my_work <- read_vector(pages_path, "not_my_work")

bib <- read_bib("bibliography/bibliography.bib")
by_hand <- read_excel("data/projects_by_hand.xlsx")

# `kind` comes from the section a work appears in, because the bib cannot supply
# it: book reviews and crowdsourced collaborations are both @article. Where a
# work has no section (everything staged), fall back to the bib category.
kind_from_section <- c(
  "Books" = "book",
  "Articles" = "article",
  "Book reviews" = "review",
  "Crowdsourced collaborations" = "crowdsourced",
  "Dissertation" = "dissertation"
)
kind_from_category <- c(
  "article" = "article", "book" = "book", "incollection" = "chapter",
  "inbook" = "chapter", "manual" = "software", "phdthesis" = "dissertation",
  "unpublished" = "article"
)

works <- bib |>
  select(bibtex_key, entry_type) |>
  filter(!bibtex_key %in% not_my_work) |>
  left_join(sections, by = "bibtex_key") |>
  left_join(by_hand, by = c("bibtex_key" = "BIBTEXKEY")) |>
  mutate(
    kind = coalesce(unname(kind_from_section[section]),
                    unname(kind_from_category[entry_type])),
    stage = if_else(bibtex_key %in% no_page_yet, "staged", "published"),
    has_custom = bibtex_key %in% custom_pages
  )

# Assets are recorded from what is on disk, not from what a spreadsheet claims.
asset_entry <- function(dir, file, recipe = NULL) {
  if (is.na(file) || !file.exists(file.path(dir, file))) return(NULL)
  compact(list(file = file, recipe = recipe))
}

yaml_for <- function(row) {
  id <- row$bibtex_key

  display_file <- if (!is.na(row$display_figure)) basename(row$display_figure) else NA_character_
  card_file <- str_c(id, "_card.png")
  cover_file <- str_c(id, "_cover.jpg")

  card_recipe <- if (row$kind == "book") "make_card_images.R:cover" else "make_card_images.R:paper"

  links <- list(
    paper = row$paper_url %|% NULL,
    appendix = row$appendix_url %|% NULL,
    journal = row$journal_url %|% NULL,
    replication_archive = row$replication_url %|% NULL,
    preanalysis_plans = compact(list(row$pap_url_1 %|% NULL, row$pap_url_2 %|% NULL,
                                     row$pap_url_3 %|% NULL)),
    project = row$project_url %|% NULL,
    extra = list()
  )

  assets <- list(
    display = if (!is.na(display_file)) compact(list(
      file = display_file, recipe = NULL, source = NULL, gloss = NULL
    )) else NULL,
    card = asset_entry("card_figures", card_file, card_recipe),
    cover = asset_entry("book_covers", cover_file),
    hex = NULL
  )

  compact(list(
    work_id = id,
    bibtex_key = id,
    kind = row$kind,
    stage = row$stage,
    links = links,
    coauthors = list(),
    assets = assets,
    rights = "public",
    active_maintenance = "none"
  ))
}

`%|%` <- function(x, y) if (length(x) == 0 || is.na(x)) y else as.character(x)

migrate <- function(dry_run = TRUE) {
  written <- character()
  skipped <- character()

  for (i in seq_len(nrow(works))) {
    row <- works[i, ]
    id <- row$bibtex_key
    path <- file.path("catalog", id, "metadata", "work.yaml")

    if (file.exists(path)) { skipped <- c(skipped, id); next }
    if (dry_run) { written <- c(written, id); next }

    dir.create(file.path("catalog", id, "metadata"), recursive = TRUE, showWarnings = FALSE)
    write_yaml(yaml_for(row), path)
    written <- c(written, id)
  }

  list(written = written, skipped = skipped,
       kinds = works |> count(kind, stage) |> arrange(desc(n)))
}
