# First-page thumbnails for the project pages.
#
# The gallery card and this are different assets with different jobs, which is
# why one cannot serve both. The card is a 1000x1000 CROP of page one, square by
# construction so a grid of them tiles evenly; it necessarily cuts the page off.
# The thumbnail is the whole first page at its own proportions, so it reads as
# a paper rather than as a swatch, and it links to the PDF.

library(tidyverse)
library(magick)

source("code/harvest_works.R")

make_page1 <- function(root = ".", width = 900) {
  h <- harvest_works(root)

  papers <- h$links |>
    filter(slot == "paper", !is_url, str_ends(target, ".pdf")) |>
    select(work_id, file = target)

  made <- character()
  for (i in seq_len(nrow(papers))) {
    id <- papers$work_id[i]
    src <- file.path(works_dir(root), id, "original_materials", papers$file[i])
    dest_dir <- file.path(works_dir(root), id, "assets")
    dest <- file.path(dest_dir, str_c(id, "_page1.png"))
    if (!file.exists(src)) next
    dir.create(dest_dir, showWarnings = FALSE, recursive = TRUE)

    ok <- try({
      image_read_pdf(src, pages = 1, density = 150) |>
        image_scale(as.character(width)) |>
        image_convert(format = "png") |>
        image_write(dest)
    }, silent = TRUE)
    if (!inherits(ok, "try-error")) made <- c(made, id)
  }

  # Recorded like any other asset, with its recipe, so the source-versus-derived
  # question has the same answer here as everywhere else.
  for (id in made) {
    path <- file.path(works_dir(root), id, "metadata", "work.yaml")
    y <- yaml::read_yaml(path)
    y$assets$page1 <- list(
      file = str_c(id, "_page1.png"),
      recipe = "make_page1_thumbnails.R"
    )
    yaml::write_yaml(y, path)
  }

  list(n = length(made), ids = made)
}
