# Gallery cards, one per work, written into the work's own folder.
#
# Ported to the catalog on 2026-07-31. The previous version was the last script
# still living in the pre-catalog world: it read PDFs out of the flat
# `documents/` directory, took its key list from `bib2df` (retired in favour of
# read_bib), and wrote its output into the SITE REPO rather than into the
# catalog. That last part had become actively destructive, because the build
# now syncs with `--delete`: a card written to the repo would be deleted on the
# next build, since the build does not produce it.
#
# Cards are derived, so they belong beside the other derived images in
# `catalog/<work_id>/assets/`, which is where make_page1_thumbnails.R already
# puts the page-1 thumbnails.
#
# Only missing cards are generated. Delete a card to force it to be remade.

source("site/code/harvest_works.R")
library(magick)

make_card_images <- function(root = ".") {
  harvest <- harvest_works(root)

  works <- harvest$works |>
    mutate(
      dest = file.path(works_dir(root), work_id, "assets", str_c(work_id, "_card.png")),
      paper = file.path(works_dir(root), work_id, "original_materials",
                        str_c(work_id, ".pdf")),
      cover = file.path(works_dir(root), work_id, "original_materials",
                        str_c(work_id, "_cover.jpg"))
    ) |>
    filter(!file.exists(dest), file.exists(paper) | file.exists(cover))

  if (!nrow(works)) {
    print("cards: none missing")
    return(invisible(character()))
  }

  for (i in seq_len(nrow(works))) {
    id <- works$work_id[i]
    dir.create(dirname(works$dest[i]), showWarnings = FALSE, recursive = TRUE)

    if (file.exists(works$cover[i])) {
      # A cover is portrait (Persuasion in Parallel is 1249x1874) while every
      # other card is a 1000x1000 square, so it is FITTED and padded rather than
      # cropped: cropping a cover cuts off the title or the author. `image_resize`
      # without a "!" preserves the aspect ratio and `image_extent` centres it.
      image_read(works$cover[i]) |>
        image_resize("1000x1000") |>
        image_extent("1000x1000", color = "white") |>
        image_convert(format = "png") |>
        image_write(works$dest[i])
    } else {
      image_read_pdf(works$paper[i], pages = 1, density = 500) |>
        image_scale("1000") |>
        image_crop("1000x1000") |>
        image_convert(format = "png") |>
        image_write(works$dest[i])
    }
    print(id)
  }

  invisible(works$work_id)
}

if (!interactive() && sys.nframe() == 0) make_card_images()
