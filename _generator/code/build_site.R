# The whole build, in one call.
#
# Before this existed the routine was five Rscript invocations in a required
# order, then a render, then an rsync, then a commit, with nothing enforcing
# any of it. Two of the ordering constraints are not guessable from the code:
# `publish_assets()` must run AFTER `quarto render` (Quarto owns _site and
# writes it last), and brand.scss must be copied into the build BEFORE the
# render, or the theme compiles against a stale palette.
#
#   Rscript site/code/build_site.R          build, check, and sync to the repo
#   Rscript site/code/build_site.R --local  build and check only, no sync
#
# It refuses to sync when a check fails. The published-URL count is the one
# that matters: 217 URLs were live before the restructure and every one of them
# must still resolve, so a build that drops one is a build that breaks somebody
# else's citation.

source("site/code/build_slice.R")
source("site/code/build_galleries.R")
source("site/code/build_site_chrome.R")
source("site/code/check_links.R")
source("site/code/package_versions.R")

brand_source <- "/Users/alexandercoppock/Dropbox/claude_control/tools/brand.scss"
site_repo <- "/Users/alexandercoppock/git_projects/acoppock.github.io"

build_site <- function(root = ".", sync = TRUE) {
  message("1/6 pages")
  build_slice(root)

  message("2/6 galleries")
  build_galleries(root)

  message("3/6 chrome")
  build_site_chrome(root)

  # Before the render, not after: Quarto compiles the theme from this file.
  file.copy(brand_source, file.path(slice_dir, "brand.scss"), overwrite = TRUE)

  message("4/6 quarto render")
  render <- system2("quarto", c("render", shQuote(slice_dir)),
                    stdout = TRUE, stderr = TRUE)
  errors <- render[str_detect(render, regex("^ERROR", ignore_case = TRUE))]
  if (length(errors)) {
    message(str_flatten(errors, "\n"))
    stop("quarto render failed")
  }

  # After the render: Quarto writes _site last, so anything published before it
  # is overwritten.
  message("5/6 assets")
  assets <- publish_assets(root)

  message("6/6 checks")
  links <- check_links()

  # check_works() existed from the start and nothing ever called it, so the
  # whole catalog validation layer ran only when someone remembered to run it
  # by hand (2026-08-09). Its errors block the sync, since an error there means
  # a page rendering without a citation; its reports are counted and shown.
  harvest <- harvest_works(root)
  catalog <- check_works(harvest, root)
  catalog_errors <- catalog |> filter(severity == "error")

  # Report-only, always. A stale version is worth knowing about on every build
  # and is never a reason to refuse to publish, and an offline build resolves
  # nothing at all.
  versions <- check_package_versions(harvest)

  ok <- assets$urls_present == assets$urls_expected &&
    nrow(links$problems) == 0 &&
    nrow(catalog_errors) == 0 &&
    length(assets$leaked) == 0
  message(str_c("  published URLs: ", assets$urls_present, "/", assets$urls_expected))
  message(str_c("  book PDFs in output: ", length(assets$leaked), " (must be 0)"))
  message(str_c("  links checked: ", links$checked, ", problems: ", nrow(links$problems)))
  message(str_c("  catalog: ", nrow(catalog_errors), " errors, ",
                sum(catalog$severity == "report"), " reports"))
  message(str_c("  package versions: ", nrow(versions), " stale"))
  # Loudest failure in the build, because it is the only one whose damage is
  # not fully undoable: a book PDF that reaches the site is retrievable at a
  # commit SHA long after it is deleted.
  if (length(assets$leaked)) {
    message("  ABOUT TO PUBLISH A FULL BOOK PDF: ", str_flatten(assets$leaked, ", "))
    message("  a book's own <work_id>.pdf is never published; check its links: in work.yaml")
  }
  if (nrow(links$problems)) print(links$problems, n = 20)
  if (nrow(catalog_errors)) print(catalog_errors, n = 20)
  if (nrow(versions)) {
    print(versions, n = 20)
    message("  run: Rscript site/code/update_package_versions.R --dry-run")
  }

  if (!ok) {
    message("checks failed; NOT syncing to the site repo")
    return(invisible(list(assets = assets, links = links, synced = FALSE)))
  }

  if (!sync) {
    message("built and checked; sync skipped")
    return(invisible(list(assets = assets, links = links, synced = FALSE)))
  }

  # --delete, so a work removed from the catalog stops being published. The
  # three exclusions are repo files rather than site output; everything else the
  # site needs, including CNAME and .nojekyll, is emitted by publish_assets().
  message("sync")
  system2("rsync", c("-a", "--delete", "--exclude", ".git", "--exclude", ".gitignore",
                     "--exclude", "*.Rproj",
                     shQuote(str_c(file.path(slice_dir, "_site"), "/")),
                     shQuote(str_c(site_repo, "/"))))
  message(str_c("  synced to ", site_repo, "; review and commit"))

  invisible(list(assets = assets, links = links, synced = TRUE))
}

if (!interactive() && sys.nframe() == 0) {
  build_site(sync = !"--local" %in% commandArgs(TRUE))
}
