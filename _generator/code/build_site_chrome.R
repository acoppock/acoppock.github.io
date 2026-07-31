# The site chrome: nav, footer, stylesheets, and the two hand-written pages.
#
# Ported as-is. The restructure is verified by pages that look UNCHANGED, so
# the brand lands afterwards as its own pass.
#
# One deliberate change. The old header ends with a jQuery line that strips
# Bootstrap 3's container classes off `.main-container`. Quarto is Bootstrap 5
# and has no such element, so the line is dropped rather than ported: it would
# be a no-op at best. The wrapper divs it preceded are kept, because the site's
# own CSS is written against them.

source("code/harvest_works.R")

# The nav, footer and stylesheets are SOURCE, not build output, so they live in
# works/site_chrome/ rather than being read back out of the published repo. They
# were restored there from tag pre-quarto-20260731 when the branch removed the
# old pipeline's inputs (2026-07-31).
chrome_dir <- function(root = ".") file.path(root, "site_chrome")

build_site_chrome <- function(root = ".") {
  slice <- slice_dir

  # Stylesheets and scripts come from the site repo, which is where they live
  # today; site_images/ is the works-side copy rescued on 2026-07-30.
  for (d in c("css", "js")) {
    dir.create(file.path(slice, d), showWarnings = FALSE)
    file.copy(list.files(file.path(chrome_dir(root), d), full.names = TRUE),
              file.path(slice, d), overwrite = TRUE)
  }

  # rmarkdown.css loads AFTER the theme and opens by setting the body font and
  # colour, so it overrode cosmo + brand.scss and the site could never match the
  # pkgdown sites. Those declarations are stripped on the way in, leaving the
  # file to do what only it can do: the bands, the nav, the footer, the gallery.
  # Stripped in the COPY so the site repo's own stylesheet is untouched.
  css <- read_lines(file.path(slice, "css", "rmarkdown.css"))
  typography <- str_detect(css, 'font-family: "Source Sans Pro"') |
    str_detect(css, "^  color: #404040;") |
    str_detect(css, "^  line-height: 1.7em;")
  write_lines(css[!typography], file.path(slice, "css", "rmarkdown.css"))
  dir.create(file.path(slice, "images"), showWarnings = FALSE)
  file.copy(list.files(file.path(root, "site_images"), full.names = TRUE),
            file.path(slice, "images"), overwrite = TRUE)

  file.copy(file.path(chrome_dir(root), "project_page.css"),
            file.path(slice_dir, "project_page.css"), overwrite = TRUE)

  header <- read_lines(file.path(chrome_dir(root), "include_header.html")) |>
    discard(~ str_detect(.x, "main-container")) |>
    discard(~ str_detect(.x, "^<script|^</script>"))
  write_lines(header, file.path(slice, "_before_body.html"))

  file.copy(file.path(chrome_dir(root), "include_footer.html"),
            file.path(slice, "_after_body.html"), overwrite = TRUE)

  # The Google Analytics block in the site's head uses a UA- property, which
  # Universal Analytics retired in 2023, so it is dead code that still fires a
  # request. Ported for fidelity; flagged rather than silently dropped.
  head_html <- read_lines(file.path(chrome_dir(root), "include_head.html"))
  write_lines(head_html, file.path(slice, "_in_header.html"))

  write_lines(c(
    "project:",
    "  type: default",
    "  output-dir: _site",
    "  # resources is a PROJECT key. Placed under format: it is silently ignored,",
    "  # which is how the site rendered with 8 of 25 images and no home picture.",
    "  resources:",
    "    - images",
    "    - js",
    "    - card_figures",
    "    - display_figures",
    "    - book_covers",
    "    - page1",
    "format:",
    "  html:",
    "    # cosmo + brand.scss, the same pair the six pkgdown sites run. The old",
    "    # site loaded bootstrap-3.3.5/cosmo.min.css and rmarkdown.css was written",
    "    # to sit ON TOP of it, so `theme: none` stripped the baseline: images lost",
    "    # `max-width: 100%` and rendered at their natural 1000px, and the type lost",
    "    # cosmo's scale entirely.",
    "    theme:",
    "      - cosmo",
    "      - brand.scss",
    "    toc: false",
    "    # The site does its own banding, so Quarto must not impose an article",
    "    # column: measured, its default capped main.content at 612px and the",
    "    # gallery band at 551px, which is what made every card cramped.",
    "    page-layout: full",
    "    css:",
    "      - css/reset.css",
    "      - css/rmarkdown.css",
    "      - project_page.css",
    "    include-in-header: _in_header.html",
    "    include-before-body: _before_body.html",
    "    include-after-body: _after_body.html"
  ), file.path(slice, "_quarto.yml"))

  # Home. Hand-written, and its bands use the site's own CSS classes rather
  # than any framework, so it ports verbatim.
  write_lines(str_c(
    '---\ntitle: ""\npagetitle: "Alexander Coppock"\n---\n\n',
    '<div id="homeContent">\n',
    '<div class="band full blue first leftText">\n',
    '<div class="bandContent vCenter">\n',
    '<div class="blurb">\n',
    '<div>I am an Associate Professor of Political Science at Northwestern University. ',
    'I\'m the author of <a href="coppock_2022.html">Persuasion in Parallel</a> and a member of the ',
    '<a href="https://declaredesign.org/">DeclareDesign</a> team. ',
    'You can find my <a href="coppock_cv.pdf">CV here</a>.</div>\n',
    '</div>\n</div>\n',
    '<img class="imageTwo" src="images/front_page.png"/>\n',
    '</div>\n</div>\n'
  ), file.path(slice, "index.qmd"))

  # Notes stays hand-curated by decision: generating it from a directory would
  # publish whatever sits in subpages/, which is precisely the judgement Alex
  # keeps making by hand. What changed (2026-07-31) is only its PRESENTATION:
  # cards like the galleries, rather than a bare list of links. The thumbnail
  # for a PDF note is its first page; for the one HTML note it is a screenshot
  # of the page itself.
  dir.create(file.path(slice, "note_thumbs"), showWarnings = FALSE)
  file.copy(list.files(file.path(root, "subpages", "thumbs"), full.names = TRUE),
            file.path(slice, "note_thumbs"), overwrite = TRUE)

  notes <- tribble(
    ~href, ~thumb, ~title, ~extra,
    "note_Random_Assignment_Subject_To_Constraints.pdf",
      "note_Random_Assignment_Subject_To_Constraints.png",
      "Random assignment subject to constraints", "",
    "subpages/counterfactual_format.html", "counterfactual_format.png",
      "How to use the counterfactual format",
      " with <a href=\"https://m-graham.com//\">Matt Graham</a>",
    "attention.pdf", "attention.png", "Notes on attention", "",
    "testing_with_grf.pdf", "testing_with_grf.png",
      "Note on testing for heterogeneity with grf",
      " with <a href=\"https://mollyow.github.io/\">Molly Offer-Westort</a>"
  )

  note_cards <- notes |>
    glue_data(
      "<div class='noteCard'>",
      "<a href='{href}'><img src='note_thumbs/{thumb}' alt='{title}'/></a>",
      "<div class='noteCardTitle'><a href='{href}'>{title}</a>{extra}</div>",
      "</div>"
    ) |>
    str_flatten("\n")

  write_lines(str_c(
    '---\ntitle: ""\npagetitle: "Notes"\n---\n\n',
    '<div class="noteGrid">\n', note_cards, '\n</div>\n'
  ), file.path(slice, "notes.qmd"))

  invisible(TRUE)
}
