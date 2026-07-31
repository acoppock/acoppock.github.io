rm(list = ls())
library(magick)
library(magrittr)
library(pdftools)

# For papers --------------------------------------------------------------
# Generates only the cards that are MISSING, rather than whichever index happened to
# be assigned to `i`. The old form hardcoded `i <- 31`, so running the script wrote
# one arbitrary card: on 2026-07-29 that silently produced an unreferenced
# coppock_green_porter_2026_preprint_card.png, and it also meant a genuinely missing
# card was never noticed.
#
# Restricted to stems that are bib keys, which keeps preprint and other suffixed PDFs
# in documents/ from acquiring cards nothing will ever reference.
library(tidyverse)
library(bib2df)

keys <- suppressWarnings(bib2df("bibliography/bibliography.bib"))$BIBTEXKEY

files <- list.files(path = "documents/", pattern = "[.]pdf$")
files <- files[!grepl("appendix", files)]
file_names <- gsub(pattern = "[.]pdf$", replacement = "", x = files)

card_dir <- path.expand("~/git_projects/acoppock.github.io/card_figures")
wanted <- tibble(file = files, key = file_names) |>
  filter(key %in% keys) |>
  filter(!file.exists(file.path(card_dir, paste0(key, "_card.png"))))

if (nrow(wanted) == 0) {
  print("paper cards: none missing")
} else {
  for (i in seq_len(nrow(wanted))) {
    try(image_read_pdf(paste0("documents/", wanted$file[i]), pages = 1, density = 500) |>
          image_scale("1000") |>
          image_crop("1000x1000") |>
          image_convert(format = "png") |>
          image_write(file.path(card_dir, paste0(wanted$key[i], "_card.png"))))
    print(wanted$key[i])
  }
}


# For books ---------------------------------------------------------------
# A book has no paper PDF in documents/, so the loop above cannot make its card and
# the gallery fell back to a title-only entry. The card is made from the cover
# instead, kept in book_covers/<key>_cover.jpg.
#
# Covers are portrait (Persuasion in Parallel is 1249x1874) while every other card is
# a 1000x1000 square, so the cover is FITTED inside the square and padded with white
# rather than cropped: cropping a cover cuts off the title or the author, and the
# page background is #fff so the padding is invisible. `image_resize` without a "!"
# preserves the aspect ratio, and `image_extent` centres it on the square canvas.
#
# Runs over the whole directory rather than by index, so adding a cover is enough.
covers <- list.files("book_covers", pattern = "_cover\\.(jpg|jpeg|png)$")

for (cover in covers) {
  key <- sub("_cover\\.(jpg|jpeg|png)$", "", cover)
  image_read(file.path("book_covers", cover)) |>
    image_resize("1000x1000") |>
    image_extent("1000x1000", color = "white") |>
    image_convert(format = "png") |>
    image_write(paste0("~/git_projects/acoppock.github.io/card_figures/", key, "_card.png"))
  print(key)
}



