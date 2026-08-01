# Layer 2 of the new site: read the paper folders, join the bibliography, and
# return tidy tables. Pure. Reads, writes nothing.
#
# The bib owns author/title/journal/year/volume/number/pages/DOI; paper.yaml
# owns links, kind, stage, assets, rights and never restates a bib field. The
# join is bibtex_key.

library(tidyverse)
library(glue)
library(yaml)
library(readxl)

source("code/read_bib.R")

# Paper folders live under original_materials/ (Alex, 2026-07-30), which keeps
# the 70 of them out of the type-based directories at the top of works/ and
# matches the original_materials/<work_id>/ convention the meta-analysis
# projects already use.
works_dir <- function(root = ".") file.path(root, "catalog")

harvest_works <- function(root = ".") {
  work_dirs <- list.dirs(works_dir(root), recursive = FALSE) |>
    keep(~ file.exists(file.path(.x, "metadata", "work.yaml")))

  meta <- work_dirs |>
    set_names(basename) |>
    map(~ read_yaml(file.path(.x, "metadata", "work.yaml")))

  works_tbl <- imap(meta, function(m, id) {
    tibble(
      work_id = id,
      bibtex_key = m$bibtex_key %||% NA_character_,
      kind = m$kind %||% NA_character_,
      stage = m$stage %||% NA_character_,
      rights = m$rights %||% NA_character_,
      active_maintenance = m$active_maintenance %||% NA_character_,
      has_custom = file.exists(file.path(works_dir(root), id, "metadata", "custom.md"))
    )
  }) |>
    list_rbind()

  # Named slots and the labelled extras land in one table, distinguished by
  # `slot`, so a page template iterates once and check_works() tests once.
  named_slots <- c("paper", "appendix", "journal", "replication_archive", "project")

  links <- imap(meta, function(m, id) {
    named <- named_slots |>
      map(function(s) {
        v <- m$links[[s]]
        if (is.null(v)) return(NULL)
        tibble(work_id = id, slot = s, label = NA_character_, target = as.character(v))
      }) |>
      list_rbind()

    paps <- m$links$preanalysis_plans %||% list()
    pap_rows <- if (length(paps)) {
      tibble(work_id = id, slot = "preanalysis_plan", label = NA_character_,
             target = as.character(unlist(paps)))
    } else NULL

    extras <- m$links$extra %||% list()
    extra_rows <- if (length(extras)) {
      map(extras, ~ tibble(
        work_id = id, slot = "extra",
        label = .x$label %||% NA_character_,
        target = as.character(.x$url %||% .x$file)
      )) |> list_rbind()
    } else NULL

    bind_rows(named, pap_rows, extra_rows)
  }) |>
    list_rbind() |>
    mutate(is_url = str_starts(target, "http"))

  # A work that folds another into it. The superseded id keeps its published
  # URL through a stub page rather than 404ing, which is how a merge respects
  # the URL policy.
  supersedes <- imap(meta, function(m, id) {
    ids <- m$supersedes %||% list()
    if (!length(ids)) return(NULL)
    tibble(work_id = id, superseded = as.character(unlist(ids)))
  }) |>
    list_rbind()

  # Files that must exist at the published root even though NO page links them.
  # Found in Phase 3: 15 preprint and alternate-appendix PDFs are live, citable,
  # and linked from nowhere, so a generated build would have dropped them. They
  # are exactly the un-redirectable PDFs the URL policy exists to protect.
  published_files <- imap(meta, function(m, id) {
    files <- m$published_files %||% list()
    if (!length(files)) return(NULL)
    tibble(work_id = id, file = as.character(unlist(files)))
  }) |>
    list_rbind()

  # DERIVED, not stored (2026-07-30). Coauthors are the bib's author list
  # intersected with the people who have a website on file, so recording them in
  # paper.yaml stored the bib's own facts a second time. The migration wrote
  # `coauthors: []` for all 67 works and silently dropped ~60 coauthor links
  # from the pages, which is what storing a derivable fact buys you.
  coauthor_file <- read_excel(file.path(root, "data", "coauthors_by_hand.xlsx"))
  bib_early <- read_bib(file.path(root, "bibliography", "bibliography.bib"))

  # Matched on first initial plus surname rather than on the exact string. The
  # bib and the coauthors file disagree on punctuation and middle initials
  # ("Matthew H Graham" against "Matthew H. Graham", "Ben M. Tappin" against
  # "Ben Tappin"), and an exact join drops those links silently.
  name_key <- function(x) {
    x |>
      stri_trans_general("Latin-ASCII") |>
      str_replace_all("[^A-Za-z ]", " ") |>
      str_squish() |>
      str_to_lower() |>
      (\(s) str_c(str_sub(s, 1, 1), "_", word(s, -1)))()
  }

  coauthors <- works_tbl |>
    select(work_id, bibtex_key) |>
    left_join(bib_early |> select(bibtex_key, author_parsed), by = "bibtex_key") |>
    mutate(people = map(author_parsed, ~ if (is.null(.x)) character() else .x$full_name)) |>
    select(work_id, people) |>
    unnest(people) |>
    mutate(k = name_key(people)) |>
    inner_join(coauthor_file |> select(slug, full_name) |> mutate(k = name_key(full_name)),
               by = "k") |>
    select(work_id, slug, bib_name = people)

  assets <- imap(meta, function(m, id) {
    roles <- names(m$assets %||% list())
    roles |>
      map(function(r) {
        a <- m$assets[[r]]
        if (is.null(a)) return(NULL)
        tibble(
          work_id = id, role = r,
          file = a$file %||% NA_character_,
          recipe = a$recipe %||% NA_character_,
          source = a$source %||% NA_character_,
          gloss = a$gloss %||% NA_character_,
          figure_label = a$figure_label %||% NA_character_,
          # Where the figure came from, when it was not the paper. One display
          # figure is from an AJPS blog post rather than the article.
          figure_source = a$figure_source %||% NA_character_,
          caption = a$caption %||% NA_character_
        )
      }) |>
      list_rbind()
  }) |>
    list_rbind()

  # read_bib() rather than bib2df: it matches braces instead of guessing at line
  # endings, so an entry's final field survives; it converts LaTeX accents to
  # UTF-8; and it splits names by BibTeX's rules. See notes/port_audit_20260730.md
  # for the four workarounds it retires.
  bib <- bib_early

  list(works = works_tbl, links = links, coauthors = coauthors, assets = assets,
       supersedes = supersedes,
       published_files = published_files, bib = bib)
}

# Every check returns rows rather than stopping, so one run reports everything
# wrong instead of the first thing wrong.
check_works <- function(harvest, root = ".") {
  issue <- function(work_id, severity, check, detail) {
    tibble(work_id = work_id, severity = severity, check = check, detail = detail)
  }

  works_tbl <- harvest$works
  bib_keys <- harvest$bib$bibtex_key

  missing_bib <- works_tbl |>
    filter(!bibtex_key %in% bib_keys) |>
    transmute(work_id, severity = "error", check = "bib join",
              detail = str_c("bibtex_key '", bibtex_key, "' is not in bibliography.bib"))

  # A bib entry with no folder is LEGAL (Alex, 2026-07-30): the bib's scope is
  # set by its consumer, the CV, not by authorship, so it holds reviews of
  # Alex's work and anything else the CV cites. Reported for triage, never fatal.
  orphan_bib <- tibble(bibtex_key = setdiff(bib_keys, works_tbl$bibtex_key)) |>
    transmute(work_id = bibtex_key, severity = "report", check = "bib entry with no folder",
              detail = "legal: bib scope is the CV's needs. Triage by hand.")

  # `kind` is the SITE GROUPING, not the publication type: the bib already owns
  # the latter as `entry_type`. That is why `review` and `crowdsourced` are
  # kinds even though both are @article, and why coppock_2020 is `article`
  # despite being @incollection, since the site lists it under Articles.
  # review / crowdsourced / dissertation were added 2026-07-30 during Phase 3,
  # when the migration met the five sections the live site actually has.
  bad_kind <- works_tbl |>
    filter(!kind %in% c("article", "book", "chapter", "software", "note",
                        "review", "crowdsourced", "dissertation")) |>
    transmute(work_id, severity = "error", check = "kind", detail = str_c("unknown kind '", kind, "'"))

  bad_stage <- works_tbl |>
    filter(!stage %in% c("published", "working", "staged")) |>
    transmute(work_id, severity = "error", check = "stage", detail = str_c("unknown stage '", stage, "'"))

  # A work's files live in its own folder. The flat directories remain as a
  # fallback for what has not moved (site content with no work, such as the
  # syllabi and the notes PDFs), so this resolves during and after the
  # migration rather than only after it.
  find_file <- function(f, id = NULL) {
    if (is.na(f)) return(NA_character_)
    own <- if (!is.null(id)) {
      file.path(works_dir(root), id, c("original_materials", "assets", "metadata"), f)
    } else character()
    flat <- file.path(root, c("documents", "display_figures", "card_figures",
                              "book_covers", "site_images"), f)
    hit <- c(own, flat)[file.exists(c(own, flat))]
    if (length(hit)) hit[1] else NA_character_
  }

  asset_files <- harvest$assets |>
    filter(!is.na(file)) |>
    mutate(found = map2_chr(file, work_id, find_file)) |>
    filter(is.na(found)) |>
    transmute(work_id, severity = "error", check = "asset file",
              detail = str_c(role, ": '", file, "' not found on disk"))

  link_files <- harvest$links |>
    filter(!is_url) |>
    mutate(found = map2_chr(target, work_id, find_file)) |>
    filter(is.na(found)) |>
    transmute(work_id, severity = "error", check = "link target",
              detail = str_c(slot, ": '", target, "' not found on disk"))

  published_missing <- harvest$published_files |>
    mutate(found = map2_chr(file, work_id, find_file)) |>
    filter(is.na(found)) |>
    transmute(work_id, severity = "error", check = "published file",
              detail = str_c("'", file, "' is recorded as published but is not on disk"))

  coauthor_file <- read_excel(file.path(root, "data", "coauthors_by_hand.xlsx"))
  bad_coauthors <- harvest$coauthors |>
    filter(!slug %in% coauthor_file$slug) |>
    transmute(work_id, severity = "error", check = "coauthor slug",
              detail = str_c("'", slug, "' is not in coauthors_by_hand.xlsx"))

  # A display asset with no gloss is the thing vn_20 asked for and no current
  # page has. Reported, not fatal, because the glosses are written by hand.
  missing_gloss <- harvest$assets |>
    filter(role == "display", !is.na(file), is.na(gloss)) |>
    transmute(work_id, severity = "report", check = "gloss",
              detail = "display asset has no gloss")

  missing_abstract <- works_tbl |>
    filter(kind %in% c("article", "book", "chapter")) |>
    mutate(path = file.path(works_dir(root), work_id, "metadata", "abstract.txt")) |>
    filter(!file.exists(path)) |>
    transmute(work_id, severity = "report", check = "abstract",
              detail = "no metadata/abstract.txt")

  bind_rows(missing_bib, bad_kind, bad_stage, asset_files, link_files, published_missing,
            bad_coauthors, missing_gloss, missing_abstract, orphan_bib) |>
    arrange(factor(severity, levels = c("error", "report")), work_id)
}

# Social preview tags. Quarto's own `open-graph` option belongs to the website
# project type and this project is `type: default`, so the tags are emitted per
# page instead. `header-includes` rather than `include-in-header`, because the
# latter is already set at project level and a document-level value would
# replace it rather than add to it.
#
# Without these, a link to any page posted on Bluesky or Slack rendered as a
# bare URL: no title, no description, no image, though all three were already
# generated for every work.
SITE_URL <- "https://alexandercoppock.com"

og_escape <- function(x) {
  x |>
    str_replace_all("&", "&amp;") |>
    str_replace_all('"', "&quot;") |>
    str_replace_all("<", "&lt;") |>
    str_replace_all(">", "&gt;") |>
    str_squish()
}

og_front_matter <- function(page_title, description, image, url, type = "website") {
  # Platforms cut descriptions around 200 characters; cutting on a word here
  # means the preview ends on a word rather than mid-syllable.
  desc <- og_escape(description)
  if (str_length(desc) > 200) {
    desc <- str_c(str_trim(str_sub(desc, 1, 197) |> str_remove("\\S*$")), "...")
  }
  tags <- c(
    str_c('<meta property="og:type" content="', type, '">'),
    str_c('<meta property="og:title" content="', og_escape(page_title), '">'),
    str_c('<meta property="og:description" content="', desc, '">'),
    str_c('<meta property="og:url" content="', SITE_URL, "/", url, '">'),
    str_c('<meta property="og:site_name" content="Alexander Coppock">'),
    str_c('<meta property="og:image" content="', SITE_URL, "/", image, '">'),
    '<meta name="twitter:card" content="summary">',
    str_c('<meta name="description" content="', desc, '">')
  )
  str_c('header-includes: |\n', str_flatten(str_c("  ", tags), "\n"), "\n")
}
