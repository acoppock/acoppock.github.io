# Link checker for the built site.
#
# The URL check in publish_assets() asks whether the site still SERVES the URLs
# it used to. This asks the opposite question: whether the links the site itself
# contains actually resolve. Neither implies the other, and nothing was checking
# the second, which is how a dead link to Matt Graham's paper sat in the
# counterfactual format note (2026-07-31).
#
#   check_links()                 internal only, fast, safe to run every build
#   check_links(external = TRUE)  also fetches every off-site URL

library(tidyverse)

# Attributes worth following. `src` covers images and scripts, `href` covers
# links and stylesheets.
extract_links <- function(file) {
  html <- read_file(file)
  tibble(
    page = basename(file),
    target = c(
      str_match_all(html, 'href="([^"]+)"')[[1]][, 2],
      str_match_all(html, 'src="([^"]+)"')[[1]][, 2]
    )
  )
}

classify <- function(target) {
  case_when(
    str_starts(target, "#") ~ "anchor",
    str_starts(target, "mailto:") ~ "mailto",
    str_starts(target, "data:") ~ "data",
    str_detect(target, "^https?://") ~ "external",
    TRUE ~ "internal"
  )
}

check_links <- function(site = "/Users/alexandercoppock/git_projects/acoppock.github.io/_build/_site",
                        external = FALSE, workers = 8) {
  pages <- list.files(site, pattern = "\\.html$", full.names = TRUE)

  links <- pages |>
    map(extract_links) |>
    list_rbind() |>
    mutate(kind = classify(target)) |>
    filter(!kind %in% c("anchor", "mailto", "data"))

  # A relative link may carry a fragment or a query, and a bare directory means
  # its index.html. Resolve to the file the browser would actually request.
  internal <- links |>
    filter(kind == "internal") |>
    mutate(
      path = target |> str_remove("[#?].*$") |> str_replace_all("%20", " "),
      resolved = file.path(site, path),
      resolved = if_else(dir.exists(resolved), file.path(resolved, "index.html"), resolved),
      ok = file.exists(resolved)
    )

  result <- internal |>
    filter(!ok) |>
    transmute(page, target, kind, status = "missing file")

  if (external) {
    urls <- links |> filter(kind == "external") |> distinct(target) |> pull(target)

    # Fetched in parallel through curl, deduplicated first: the same DOI appears
    # on many pages and there is no reason to ask a publisher about it twice.
    tmp_in <- tempfile(); tmp_out <- tempfile()
    write_lines(urls, tmp_in)
    system2("xargs", c("-P", workers, "-I{}", "curl", "-s", "-L", "-o", "/dev/null",
                       "--max-time", "25", "-w", shQuote("%{http_code} {}\\n"), "{}"),
            stdin = tmp_in, stdout = tmp_out)

    fetched <- read_lines(tmp_out) |>
      str_match("^(\\d+) (.*)$") |>
      as_tibble(.name_repair = "minimal") |>
      set_names(c("raw", "code", "target")) |>
      filter(!is.na(code)) |>
      mutate(code = as.integer(code)) |>
      select(target, code)

    bad_external <- links |>
      filter(kind == "external") |>
      distinct(page, target, kind) |>
      left_join(fetched, by = "target") |>
      # 000 is curl's own failure (DNS, TLS, timeout), and 4xx/5xx are the
      # server's. 403 is reported but often a bot block rather than a dead link.
      filter(is.na(code) | code == 0 | code >= 400) |>
      transmute(page, target, kind, status = if_else(is.na(code) | code == 0,
                                                     "unreachable", as.character(code)))

    result <- bind_rows(result, bad_external)
  }

  list(
    checked = nrow(links),
    internal = sum(links$kind == "internal"),
    external = n_distinct(links$target[links$kind == "external"]),
    problems = result |> arrange(status, page)
  )
}
