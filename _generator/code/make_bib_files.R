# make_bib_files.R
#
# Split bibliography/bibliography.bib into one .txt file per entry for the website
# (bibliography/separate_bib_files/<BIBTEXKEY>.txt), keeping only the fields we want
# on the internet (citation display fields, including doi) and dropping BibDesk
# bookkeeping (abstract, date-added/modified, bdsk-url-*, eprint, url, month).
#
# Reads bibliography.bib DIRECTLY -- no BibDesk "special template" export step.
# Idempotent: deterministic output (canonical field order, normalized field names),
# and it deletes any stale .txt whose key is no longer in the bib.

library(tidyverse)

bib_path <- "bibliography/bibliography.bib"
out_dir <- "bibliography/separate_bib_files"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Fields to publish, in canonical output order. Anything not here is dropped.
keep_order <- c("author", "editor", "title", "booktitle", "journal", "year",
                "volume", "number", "pages", "publisher", "address", "series",
                "edition", "chapter", "institution", "school", "organization",
                "howpublished", "note", "doi")

# Strip a trailing entry-closing brace (when it sits on the same line as the last
# field) and a trailing comma, leaving the field's own braces/quotes intact.
clean_value <- function(rest) {
  rest <- str_trim(rest)
  if (str_count(rest, fixed("}")) > str_count(rest, fixed("{")) && str_ends(rest, fixed("}"))) {
    rest <- str_sub(rest, 1, -2)
  }
  rest <- str_replace(str_trim(rest), ",$", "")
  str_trim(rest)
}

parse_entry <- function(chunk) {
  head <- str_match(chunk, "^\\s*@(\\w+)\\s*\\{\\s*([^,\\s]+)\\s*,")
  if (is.na(head[1, 1])) return(NULL)
  type <- str_to_lower(head[1, 2])
  key <- head[1, 3]

  lines <- str_split(chunk, "\n")[[1]][-1]           # drop the @type{key, line
  fields <- list()
  for (ln in lines) {
    m <- str_match(ln, "^\\s*([A-Za-z][A-Za-z-]*)\\s*=\\s*(.*)$")
    if (is.na(m[1, 1])) next                          # closing "}" or blank line
    name <- str_to_lower(m[1, 2])
    if (!name %in% keep_order) next
    if (!name %in% names(fields)) fields[[name]] <- clean_value(m[1, 3])
  }
  list(type = type, key = key, fields = fields)
}

format_entry <- function(e) {
  present <- keep_order[keep_order %in% names(e$fields)]
  body <- map_chr(present, ~ str_c("  ", .x, " = ", e$fields[[.x]]))
  str_c("@", e$type, "{", e$key, ",\n",
        str_c(body, collapse = ",\n"), "\n}\n")
}

# --- split the .bib into entry chunks (fields are one-per-line, so entries are
#     delimited by a line-initial @) and write one cleaned file per key ----
raw <- read_file(bib_path)
chunks <- str_split(raw, "\\n(?=@)")[[1]]
chunks <- chunks[str_detect(chunks, "^\\s*@\\w+\\s*\\{")]

entries <- compact(map(chunks, parse_entry))
keys <- map_chr(entries, "key")

walk(entries, ~ write_file(format_entry(.x),
                           file.path(out_dir, str_c(.x$key, ".txt"))))

# --- idempotent cleanup: remove files for keys no longer in the bib ----
existing <- list.files(out_dir, pattern = "\\.txt$")
stale <- setdiff(existing, str_c(keys, ".txt"))
if (length(stale) > 0) file.remove(file.path(out_dir, stale))

message(str_glue("Wrote {length(keys)} entries to {out_dir}/ ",
                 "(removed {length(stale)} stale file(s))."))
