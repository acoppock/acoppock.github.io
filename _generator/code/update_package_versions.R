# Rewrite the version and year of every package entry in the bibliography from
# what CRAN and GitHub actually serve. The reporting half of this lives in
# site/code/package_versions.R and runs on every build; this is the half that
# writes, and it is a separate command on purpose, so the hand layer is never
# edited as a side effect of building the site.
#
# Run from the works/ root:
#   Rscript site/code/update_package_versions.R --dry-run   show what would change
#   Rscript site/code/update_package_versions.R             apply it
#
# The year moves only for a package on CRAN, which is the only source that
# knows a release date. A development version keeps whatever year the bib says.

source("site/code/harvest_works.R")
source("site/code/package_versions.R")

dry_run <- "--dry-run" %in% commandArgs(trailingOnly = TRUE)

bib_path <- "bibliography/bibliography.bib"
lines <- read_lines(bib_path)

resolved <- resolve_package_versions(harvest_works("."))

# The entry runs from its @type{key, line to the line before the next entry.
# Fields are matched inside that window rather than globally, since `note` and
# `year` appear in most of the 80-odd entries in this file.
entry_range <- function(key) {
  starts <- str_which(lines, "^@")
  start <- str_which(lines, str_c("^@\\w+\\{", str_escape(key), ","))
  if (length(start) != 1) return(NULL)
  after <- starts[starts > start]
  end <- if (length(after)) after[1] - 1 else length(lines)
  start:end
}

# Substitutes the value and leaves everything else on the line alone, so the
# tab, the spacing and the trailing comma or brace survive untouched.
set_field <- function(range, field, value) {
  hit <- range[str_detect(lines[range], str_c("^\\s*", field, " = \\{"))]
  if (!length(hit)) return(FALSE)
  lines[hit[1]] <<- str_replace(lines[hit[1]], "\\{[^}]*\\}", str_c("{", value, "}"))
  TRUE
}

changes <- list()

for (i in seq_len(nrow(resolved))) {
  row <- resolved[i, ]
  if (row$source == "unresolved") next

  range <- entry_range(row$bibtex_key)
  if (is.null(range)) {
    changes <- append(changes, list(str_c("SKIPPED ", row$work_id,
                                          ": no unique bib entry for '", row$bibtex_key, "'")))
    next
  }

  if (!is.na(row$bib_version) && row$bib_version != row$version) {
    note <- str_c("R package version ", row$version)
    if (set_field(range, "note", note)) {
      changes <- append(changes, list(str_c(row$work_id, " version ", row$bib_version,
                                            " -> ", row$version, " (", row$source, ")")))
    } else {
      changes <- append(changes, list(str_c("SKIPPED ", row$work_id, ": no note field to update")))
    }
  }

  if (!is.na(row$year) && as.character(row$bib_year) != row$year) {
    if (set_field(range, "year", row$year)) {
      changes <- append(changes, list(str_c(row$work_id, " year ", row$bib_year,
                                            " -> ", row$year, " (", row$source, ")")))
    } else {
      changes <- append(changes, list(str_c("SKIPPED ", row$work_id, ": no year field to update")))
    }
  }
}

if (!length(changes)) {
  print("every package entry already matches CRAN and GitHub; nothing to do")
} else {
  print(str_c(if (dry_run) "DRY RUN: " else "applied: ", length(changes), " change(s)"))
  walk(changes, print)
  if (!dry_run) write_lines(lines, bib_path)
  if (dry_run) print("nothing written; re-run without --dry-run to apply")
}
