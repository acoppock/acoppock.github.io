# Move each work's files out of the type-based directories and into its own
# folder under catalog/.
#
# The split is by PROVENANCE, using the `recipe` field rather than the file
# type: an asset with no recipe is irreplaceable and belongs in
# original_materials/, an asset something regenerates belongs in assets/. That
# is the field earning its place, and it replaces the exception list the
# 2026-07-29 discussion could not avoid.
#
#   catalog/<work_id>/original_materials/   paper, appendix, preprints, display figure, cover, hex
#   catalog/<work_id>/metadata/             work.yaml, custom.md
#   catalog/<work_id>/assets/               cards and anything else with a recipe

source("code/harvest_works.R")

source_dirs <- c("documents", "display_figures", "card_figures", "book_covers")

locate <- function(file) {
  hits <- file.path(source_dirs, file)
  hits <- hits[file.exists(hits)]
  if (length(hits)) hits[1] else NA_character_
}

plan_moves <- function(root = ".") {
  h <- harvest_works(root)

  # Everything a page links that is a local file, plus the files published at a
  # URL with nothing linking them. Both are originals.
  linked <- h$links |>
    filter(!is_url) |>
    transmute(work_id, file = target, dest = "original_materials")

  published <- h$published_files |>
    transmute(work_id, file, dest = "original_materials")

  assets <- h$assets |>
    filter(!is.na(file)) |>
    transmute(work_id, file,
              dest = if_else(is.na(recipe), "original_materials", "assets"))

  bind_rows(linked, published, assets) |>
    distinct(work_id, file, .keep_all = TRUE) |>
    mutate(from = map_chr(file, locate)) |>
    filter(!is.na(from)) |>
    mutate(to = file.path(works_dir(root), work_id, dest, file))
}

move_files <- function(root = ".", dry_run = TRUE) {
  moves <- plan_moves(root)

  if (!dry_run) {
    walk(unique(dirname(moves$to)), dir.create, recursive = TRUE, showWarnings = FALSE)
    ok <- map2_lgl(moves$from, moves$to, file.rename)
    moves$moved <- ok
  }

  list(
    n = nrow(moves),
    by_dest = moves |> count(dest),
    remaining_flat = tibble(dir = source_dirs,
                            files = map_int(source_dirs, ~ length(list.files(.x)))),
    moves = moves
  )
}
