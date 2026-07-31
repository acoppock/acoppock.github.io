# The project page, rebuilt to Alex's brief (2026-07-31):
#   card top-left, title / citation / abstract to its right at two thirds,
#   and a STRUCTURED table of links below rather than a list dump.
#
# Two consequences fall out of the brief and are worth naming.
#
# Coauthor links leave the link block entirely. The citation already names the
# authors, so their websites belong on their names. That removes a whole
# category from what was making the list look like a dump.
#
# `show_figure` decides whether the display figure and its gloss appear at all.
# Alex is unsure they earn their place, so the switch exists to be looked at
# both ways rather than argued about.

source("code/harvest_works.R")

# No taxonomy. Every grouping scheme generated edge cases (a pre-analysis plan
# is not data, a preprint is not quite "published", a project site is neither),
# and with the coauthor links moved onto the author names most works have four
# to six links: a short row, not a dump. Order is fixed and meaningful, running
# from the paper itself outwards to the apparatus.
link_order <- c("paper", "appendix", "preprint", "journal", "replication_archive",
                "preanalysis_plan", "project", "extra", "bibtex")

link_text <- c(
  paper = "PDF", appendix = "Appendix", preprint = "Preprint",
  journal = "Journal", replication_archive = "Replication archive",
  preanalysis_plan = "Pre-analysis plan", project = "Project site",
  bibtex = "BibTeX"
)

# Author names carry their own websites, so a coauthor with a page on file is
# linked in place rather than listed again underneath.
link_authors <- function(citation, work_id, harvest, coauthor_file) {
  slugs <- harvest$coauthors |> filter(work_id == .env$work_id) |> pull(slug)
  if (!length(slugs)) return(citation)
  people <- coauthor_file |> filter(slug %in% slugs)
  for (i in seq_len(nrow(people))) {
    citation <- str_replace(
      citation,
      fixed(people$full_name[i]),
      str_c("<a href='", people$website[i], "' target='_blank'>", people$full_name[i], "</a>")
    )
  }
  citation
}

build_links_row <- function(work_id, harvest) {
  rows <- harvest$links |> filter(work_id == .env$work_id)

  extra_files <- harvest$published_files |>
    filter(work_id == .env$work_id) |>
    mutate(slot = if_else(str_detect(file, "preprint"), "preprint", "appendix")) |>
    transmute(slot, label = NA_character_, target = file)

  all_links <- bind_rows(
    rows |> select(slot, label, target),
    extra_files,
    tibble(slot = "bibtex", label = NA_character_, target = str_c(work_id, ".txt"))
  ) |>
    mutate(rank = match(slot, link_order)) |>
    filter(!is.na(rank)) |>
    arrange(rank)

  # A work can register more than one pre-analysis plan, and two links both
  # reading "Pre-analysis plan" is not a list, it is a puzzle. Numbered only
  # when there is more than one.
  anchors <- all_links |>
    mutate(text = coalesce(label, unname(link_text[slot]))) |>
    group_by(text) |>
    mutate(text = if (n() > 1) str_c(text, " ", row_number()) else text) |>
    ungroup() |>
    glue_data("<a href='{target}' target='_blank'>{text}</a>") |>
    str_flatten("\n")

  str_c("<div class='workLinks'>\n", anchors, "\n</div>")
}

build_project_page <- function(work_id, harvest, coauthor_file, root = ".",
                               show_figure = TRUE) {
  entry <- harvest$bib |> filter(bibtex_key == harvest$works$bibtex_key[harvest$works$work_id == work_id])
  kind <- harvest$works$kind[harvest$works$work_id == work_id]

  citation <- link_authors(format_citation(entry, with_title = FALSE), work_id, harvest, coauthor_file)

  abstract_path <- file.path(root, "abstracts", str_c(work_id, ".txt"))
  abstract <- if (file.exists(abstract_path)) str_trim(read_file(abstract_path)) else NA_character_

  # A book leads with its cover; everything else leads with its card, which is
  # the same image the gallery shows, so the page and the gallery agree.
  # The first page of the PDF, not the square gallery card: the card is a crop
  # and reads as a swatch, while the page reads as a paper. Books keep the cover,
  # which is their equivalent.
  cover <- harvest$assets |> filter(work_id == .env$work_id, role == "cover", !is.na(file))
  page1 <- harvest$assets |> filter(work_id == .env$work_id, role == "page1", !is.na(file))
  lead_img <- if (kind == "book" && nrow(cover)) {
    str_c("book_covers/", cover$file[1])
  } else if (nrow(page1)) {
    str_c("page1/", page1$file[1])
  } else NA_character_

  # The image is the shortest route to the paper, so it is a link to it.
  paper_link <- harvest$links |>
    filter(work_id == .env$work_id, slot %in% c("paper", "journal", "project")) |>
    slice(1) |>
    pull(target)

  # NOT indented. Pandoc reads any line starting with four spaces as an indented
  # code block, which is why the pages were printing '<h1 class="workTitle">' as
  # visible text instead of rendering it.
  header <- str_c(
    '<div class="workHeader">\n',
    '<div class="workCard">',
    if (!is.na(lead_img)) {
      img <- str_c('<img src="', lead_img, '" alt="', work_id, '"/>')
      if (length(paper_link)) str_c("<a href='", paper_link, "'>", img, "</a>") else img
    } else "",
    '</div>\n',
    '<div class="workBody">\n',
    '<h1 class="workTitle">', entry$title, '</h1>\n',
    '<div class="workCitation">', citation, '</div>\n',
    if (!is.na(abstract)) str_c('<div class="workAbstract">', abstract, '</div>\n') else "",
    '</div>\n</div>'
  )

  display <- harvest$assets |> filter(work_id == .env$work_id, role == "display", !is.na(file))
  figure <- if (show_figure && nrow(display)) {
    # The paper's own caption, prefixed with which figure it is (Alex,
    # 2026-07-31). The written glosses are kept in the metadata but no longer
    # rendered: a caption is the authors' description of their own figure and
    # needs no defending.
    label <- display$figure_label[1]
    caption <- display$caption[1]
    gloss <- if (!is.na(caption) && !is.na(label)) {
      # The extracted caption still opens with its own label, so strip it rather
      # than print "Figure 1 from paper: Figure 1. ...".
      body <- caption |>
        str_remove(regex(str_c("^\\s*", str_replace_all(label, "\\.", "\\\\."),
                               "\\s*[.:|]?\\s*"), ignore_case = TRUE)) |>
        # The Note: apparatus is KEPT (Alex, 2026-07-31): it is the authors'
        # own account of what the figure contains, and dropping it was cutting
        # captions off mid-thought. No truncation either, for the same reason.
        str_squish()
      str_c('\n<div class="workGloss"><span class="figureLabel">', label,
            ' from paper:</span> ', body, '</div>')
    } else ""
    orient <- {
      path <- file.path(works_dir(root), work_id, "original_materials", display$file[1])
      if (file.exists(path)) {
        info <- magick::image_info(magick::image_read(path))
        if (info$width >= info$height) "landscape" else "portrait"
      } else "landscape"
    }
    # ONE class, not two: pandoc keeps only the first class of a raw HTML div,
    # so "workFigure landscape" arrived in the output as plain "workFigure" and
    # the orientation rule never matched.
    str_c('<div class="workFigure-', orient, ' workFigure">\n<img src="display_figures/', display$file[1],
          '" alt="', work_id, '"/>', gloss, '\n</div>')
  } else ""

  custom_path <- file.path(works_dir(root), work_id, "metadata", "custom.md")
  custom <- if (file.exists(custom_path)) str_flatten(read_lines(custom_path), "\n") else NULL

  # `title: ""` because the page prints its own <h1> inside the header grid,
  # beside the card. Quarto's own title would sit above and duplicate it.
  str_c(
    '---\ntitle: ""\npagetitle: "', str_replace_all(entry$title, '"', "'"), '"\n---\n\n',
    # Custom content sits directly under the links, above the figure (Alex,
    # 2026-07-31). It matters for coppock_2014, where the correction notice must
    # be read before the figure it applies to; a book's reviews are unaffected,
    # since a book has no display figure and stays last either way.
    str_flatten(compact(list(header, build_links_row(work_id, harvest),
                             custom, if (nzchar(figure)) figure else NULL)), "\n\n"),
    "\n"
  )
}
