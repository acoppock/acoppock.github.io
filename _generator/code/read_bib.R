# A BibTeX reader for this project.
#
# Written 2026-07-30 to replace bib2df, whose defects had accumulated four
# separate workarounds across three scripts: it absorbs an entry's closing brace
# into that entry's final field, it silently drops the final field of the final
# entry unless the file ends with a blank line, it leaves LaTeX accent macros
# untouched, and it splits names without regard for BibTeX's own rules.
#
# The three things this gets right that the workarounds were compensating for:
# values are read by matching braces rather than by guessing at line endings,
# accents become real UTF-8 characters, and names are split the way BibTeX
# splits them.

library(tidyverse)
library(stringi)

# LaTeX accents to UTF-8 -------------------------------------------------------

# Rather than enumerate every accent-letter pair, map each accent command to its
# Unicode COMBINING mark, attach it to the letter, and let NFC composition
# produce the precomposed character. That covers every letter an accent can take
# instead of the handful somebody remembered to list.
combining_marks <- c(
  "`" = "̀", "'" = "́", "^" = "̂", "~" = "̃",
  "\"" = "̈", "=" = "̄", "." = "̇", "u" = "̆",
  "v" = "̌", "H" = "̋", "c" = "̧", "k" = "̨",
  "r" = "̊", "b" = "̱", "d" = "̣"
)

# Characters that are a command in themselves rather than an accent on a letter.
standalone <- c(
  "\\ss" = "ß", "\\aa" = "å", "\\AA" = "Å",
  "\\ae" = "æ", "\\AE" = "Æ", "\\oe" = "œ", "\\OE" = "Œ",
  "\\o" = "ø", "\\O" = "Ø", "\\l" = "ł", "\\L" = "Ł",
  "\\i" = "i", "\\j" = "j"
)

latex_to_utf8 <- function(x) {
  if (!is.character(x)) return(x)

  apply_accent <- function(s) {
    # \'{e} and \c{c}: command, optional space, letter in braces.
    s <- str_replace_all(s, "\\\\([`'^~\"=.uvHckrbd])\\s*\\{\\\\?([A-Za-z])\\}", function(m) {
      cmd <- str_match(m, "\\\\(.)")[, 2]
      letter <- str_match(m, "\\{\\\\?([A-Za-z])\\}")[, 2]
      str_c(letter, combining_marks[[cmd]])
    })
    # \'e and \~n: command applied directly to the next letter.
    s <- str_replace_all(s, "\\\\([`'^~\"=.])\\s*([A-Za-z])", function(m) {
      cmd <- str_match(m, "\\\\(.)")[, 2]
      letter <- str_match(m, "([A-Za-z])$")[, 2]
      str_c(letter, combining_marks[[cmd]])
    })
    # \c c and \v s: letter-named commands need a separator, otherwise \ss would
    # parse as \s + s. A doubled form (\cc) appears in older entries too.
    s <- str_replace_all(s, "\\\\([uvHckrbd])\\s+([A-Za-z])", function(m) {
      cmd <- str_match(m, "\\\\(.)")[, 2]
      letter <- str_match(m, "([A-Za-z])$")[, 2]
      str_c(letter, combining_marks[[cmd]])
    })
    s
  }

  x |>
    map_chr(function(s) {
      if (is.na(s)) return(NA_character_)
      s <- apply_accent(s)
      # Longest command first, so \oe is consumed before \o could match its
      # leading character. Matching is literal: composing a lookahead onto
      # fixed() silently drops the fixed semantics and turns "\\o" into the
      # regex "o", which rewrote "Marco" as "Marcø".
      for (cmd in names(standalone)[order(-str_length(names(standalone)))]) {
        s <- str_replace_all(s, fixed(cmd), standalone[[cmd]])
      }
      # Text macros, which arrive in abstracts and notes copied from publisher
      # exports. Formatting commands keep their content and lose the wrapper.
      s <- str_replace_all(s, c(
        "\\\\textendash\\s*" = "–", "\\\\textemdash\\s*" = "—",
        "\\\\textquoteright" = "’", "\\\\textquoteleft" = "‘",
        "\\\\textquotedblleft" = "“", "\\\\textquotedblright" = "”",
        "\\\\textbackslash" = "\\\\"
      ))
      s <- str_replace_all(s, "\\\\(textit|textbf|emph|texttt|textsc)\\s*\\{([^{}]*)\\}", "\\2")
      s <- str_replace_all(s, c("``" = "“", "''" = "”"))
      # BibTeX's "--" is an en dash. Skipped for URLs and DOIs, where a double
      # hyphen is a literal part of the identifier.
      if (!str_detect(s, "://|^10\\.")) s <- str_replace_all(s, "--", "–")
      # Escaped punctuation, then the protective braces BibDesk wraps titles in.
      s <- str_replace_all(s, c("\\\\&" = "&", "\\\\%" = "%", "\\\\\\$" = "$",
                                "\\\\_" = "_", "\\\\#" = "#"))
      s <- str_remove_all(s, "[{}]")
      stri_trans_nfc(str_squish(s))
    })
}

# Entry parsing ----------------------------------------------------------------

# Read one brace-delimited value starting at `i` (the opening brace), returning
# the contents and the position after the closing brace. Depth-counted, so a
# value containing braces survives, which is the whole reason bib2df's
# line-based guessing fails on the final field of an entry.
read_braced <- function(chars, i) {
  depth <- 0L
  start <- i + 1L
  repeat {
    ch <- chars[i]
    if (ch == "{") depth <- depth + 1L
    if (ch == "}") {
      depth <- depth - 1L
      if (depth == 0L) return(list(value = str_flatten(chars[start:(i - 1L)]), next_i = i + 1L))
    }
    i <- i + 1L
    if (i > length(chars)) stop("unterminated brace in bib entry")
  }
}

read_quoted <- function(chars, i) {
  start <- i + 1L
  i <- start
  depth <- 0L
  repeat {
    ch <- chars[i]
    if (ch == "{") depth <- depth + 1L
    if (ch == "}") depth <- depth - 1L
    if (ch == '"' && depth == 0L) {
      return(list(value = str_flatten(chars[start:(i - 1L)]), next_i = i + 1L))
    }
    i <- i + 1L
    if (i > length(chars)) stop("unterminated quote in bib entry")
  }
}

parse_entry <- function(chunk) {
  head <- str_match(chunk, "^\\s*@(\\w+)\\s*\\{\\s*([^,\\s]+)\\s*,")
  if (is.na(head[1, 1])) return(NULL)

  chars <- str_split_1(chunk, "")
  i <- str_length(head[1, 1]) + 1L
  fields <- list()

  while (i <= length(chars)) {
    ch <- chars[i]
    if (ch %in% c(" ", "\t", "\n", "\r", ",")) { i <- i + 1L; next }
    if (ch == "}") break                       # end of the entry

    name_start <- i
    while (i <= length(chars) && !chars[i] %in% c("=", " ", "\t", "\n")) i <- i + 1L
    field <- str_to_lower(str_flatten(chars[name_start:(i - 1L)]))

    while (i <= length(chars) && chars[i] != "=") i <- i + 1L
    i <- i + 1L
    while (i <= length(chars) && chars[i] %in% c(" ", "\t", "\n", "\r")) i <- i + 1L
    if (i > length(chars)) break

    parsed <- if (chars[i] == "{") {
      read_braced(chars, i)
    } else if (chars[i] == '"') {
      read_quoted(chars, i)
    } else {
      start <- i
      while (i <= length(chars) && !chars[i] %in% c(",", "\n", "}")) i <- i + 1L
      list(value = str_trim(str_flatten(chars[start:(i - 1L)])), next_i = i)
    }

    if (nzchar(field) && !field %in% names(fields)) fields[[field]] <- parsed$value
    i <- parsed$next_i
  }

  list(type = str_to_lower(head[1, 2]), key = head[1, 3], fields = fields)
}

# Names ------------------------------------------------------------------------

# BibTeX splits an author list on " and " at brace depth zero, and each name in
# one of three forms: "First von Last", "von Last, First", "von Last, Jr, First".
# Braced units are atomic, so "{de la Cruz}" stays one surname.
split_at_depth0 <- function(x, pattern) {
  chars <- str_split_1(x, "")
  depth <- 0L
  marks <- integer()
  for (i in seq_along(chars)) {
    if (chars[i] == "{") depth <- depth + 1L
    if (chars[i] == "}") depth <- depth - 1L
    if (depth == 0L) marks <- c(marks, i)
  }
  safe <- str_flatten(if_else(seq_along(chars) %in% marks, chars, ""))
  starts <- str_locate_all(safe, pattern)[[1]]
  if (nrow(starts) == 0) return(x)
  pieces <- character()
  prev <- 1L
  for (r in seq_len(nrow(starts))) {
    pieces <- c(pieces, str_sub(x, prev, starts[r, "start"] - 1L))
    prev <- starts[r, "end"] + 1L
  }
  c(pieces, str_sub(x, prev, -1L))
}

parse_one_name <- function(nm) {
  nm <- str_squish(nm)
  parts <- split_at_depth0(nm, ",")
  if (length(parts) == 1) {
    words <- str_split_1(str_squish(nm), " ")
    last <- words[length(words)]
    first <- str_flatten(words[-length(words)], " ")
    jr <- ""
  } else if (length(parts) == 2) {
    last <- str_squish(parts[1]); first <- str_squish(parts[2]); jr <- ""
  } else {
    last <- str_squish(parts[1]); jr <- str_squish(parts[2]); first <- str_squish(parts[3])
  }
  given <- latex_to_utf8(first)
  family <- latex_to_utf8(last)
  suffix <- latex_to_utf8(jr)
  tibble(
    first_name = given,
    last_name = family,
    suffix = suffix,
    full_name = str_squish(str_c(given, " ", family, if (nzchar(suffix)) str_c(" ", suffix) else ""))
  )
}

parse_bib_names <- function(author_field) {
  if (is.na(author_field)) return(list(NULL))
  names_raw <- split_at_depth0(author_field, "\\s+and\\s+")
  map(names_raw, parse_one_name) |> list_rbind()
}

# Reader -----------------------------------------------------------------------

read_bib <- function(path) {
  raw <- read_file(path)
  # Entries begin at a line-initial @. Splitting on that rather than on braces
  # means a stray brace inside a value cannot end an entry early.
  chunks <- str_split_1(raw, "\\n(?=@)")
  chunks <- keep(chunks, ~ str_detect(.x, "^\\s*@\\w+\\s*\\{"))

  entries <- map(chunks, parse_entry) |> compact()

  all_fields <- entries |> map(~ names(.x$fields)) |> unlist() |> unique()
  # BibDesk bookkeeping never reaches a page and only clutters the table.
  drop <- c("date-added", "date-modified", "bdsk-url-1", "bdsk-url-2", "bdsk-file-1", "local-url")
  keep_fields <- setdiff(all_fields, drop)

  out <- entries |>
    map(function(e) {
      # `entry_type` rather than `type`: BibTeX has a FIELD called type, which
      # @phdthesis uses for "PhD dissertation", and a column named for the entry
      # kind would be overwritten by it.
      row <- tibble(bibtex_key = e$key, entry_type = e$type)
      for (f in keep_fields) {
        row[[f]] <- latex_to_utf8(e$fields[[f]] %||% NA_character_)
      }
      row
    }) |>
    list_rbind()

  # The author field keeps its LaTeX until names are split, since an accent
  # macro inside a braced unit must not be mistaken for a name separator.
  raw_authors <- map_chr(entries, ~ .x$fields$author %||% NA_character_)
  out$author_parsed <- map(raw_authors, parse_bib_names)
  out
}
