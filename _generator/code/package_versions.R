# The version in a package citation is the one bib field with an authoritative
# source outside the bib, which is why it is the one field the bib should not
# own by hand. On 2026-08-09 five of the eleven packages on the Software page
# were stale, randomizr by five major versions and eleven years, because the
# moment a version changes is release day and release day happens in
# ~/git_projects with no reason to think about this tree.
#
# These functions go over the network, so they live here beside check_links()
# rather than in harvest_works.R, which is pure by contract. Nothing here can
# block a build: an offline run resolves nothing, says so, and syncs anyway. A
# stale version is a thing to fix, not a reason to refuse to publish.
#
#   resolve_package_versions(harvest)  what each package's version really is
#   check_package_versions(harvest)    issue rows wherever the bib disagrees
#
# The updater that acts on the report is site/code/update_package_versions.R.

library(tidyverse)

# Consulted only for packages CRAN does not have, so the four DeclareDesign
# packages never reach it.
package_owner <- function(pkg) {
  if (pkg %in% c("randomizr", "fabricatr", "estimatr", "DeclareDesign")) {
    "DeclareDesign"
  } else {
    "acoppock"
  }
}

# A package not on CRAN is the ordinary case for half of these, and crandb
# answers 404, so the warning is suppressed rather than printed five times a
# build. The absence is the answer, not a problem.
cran_record <- function(pkg) {
  rec <- suppressWarnings(
    tryCatch(jsonlite::fromJSON(str_c("https://crandb.r-pkg.org/", pkg)),
             error = function(e) NULL)
  )
  if (is.null(rec$Version)) NULL else rec
}

# `HEAD` rather than a branch name: these repos disagree about master and main,
# and raw.githubusercontent resolves HEAD to whichever the repo's default is.
github_version <- function(pkg) {
  url <- str_c("https://raw.githubusercontent.com/", package_owner(pkg), "/", pkg,
               "/HEAD/DESCRIPTION")
  lines <- tryCatch(suppressWarnings(read_lines(url)), error = function(e) NULL)
  hit <- str_subset(lines %||% character(), "^Version:")
  if (!length(hit)) NULL else str_trim(str_remove(hit[1], "^Version:"))
}

resolve_package_version <- function(pkg) {
  cran <- cran_record(pkg)
  if (!is.null(cran)) {
    return(tibble(source = "CRAN", version = cran$Version,
                  year = str_sub(cran$`Date/Publication` %||% NA_character_, 1, 4)))
  }

  # A development DESCRIPTION carries no release date, so the year is left to
  # the bib rather than guessed from a commit.
  gh <- github_version(pkg)
  if (!is.null(gh)) {
    return(tibble(source = "GitHub", version = gh, year = NA_character_))
  }

  tibble(source = "unresolved", version = NA_character_, year = NA_character_)
}

# `work_id` is the package name for every package in the catalog, and the bib
# key matches both. One that stopped being its own name resolves to
# "unresolved" and gets reported rather than silently skipped.
resolve_package_versions <- function(harvest) {
  harvest$works |>
    filter(kind == "software") |>
    select(work_id, bibtex_key) |>
    mutate(resolved = map(work_id, resolve_package_version)) |>
    unnest(resolved) |>
    left_join(harvest$bib |> select(bibtex_key, note, bib_year = year), by = "bibtex_key") |>
    mutate(bib_version = str_match(note, "[Rr] package version ([0-9][0-9.-]*)")[, 2])
}

check_package_versions <- function(harvest) {
  resolved <- resolve_package_versions(harvest)

  unresolved <- resolved |>
    filter(source == "unresolved") |>
    transmute(work_id, severity = "report", check = "package version",
              detail = "not on CRAN and no DESCRIPTION on GitHub; offline?")

  no_note <- resolved |>
    filter(source != "unresolved", is.na(bib_version)) |>
    transmute(work_id, severity = "report", check = "package version",
              detail = str_c("bib entry states no version; ", source, " has ", version))

  stale_version <- resolved |>
    filter(!is.na(bib_version), !is.na(version), bib_version != version) |>
    transmute(work_id, severity = "report", check = "package version",
              detail = str_c("bib says ", bib_version, "; ", source, " has ", version))

  # Only where the source knew a release date, which is CRAN alone. The year of
  # a package citation is the year of the version cited, so it goes stale in
  # step with the version and is worth reporting separately: an entry can have
  # the right version under the wrong year if only one of them was hand-fixed.
  stale_year <- resolved |>
    filter(!is.na(year), !is.na(bib_year), as.character(bib_year) != year) |>
    transmute(work_id, severity = "report", check = "package year",
              detail = str_c("bib says ", bib_year, "; ", source, " published ", version,
                             " in ", year))

  bind_rows(unresolved, no_note, stale_version, stale_year) |>
    arrange(work_id, check)
}
