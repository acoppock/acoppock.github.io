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
source("code/build_galleries.R")

# The nav, footer and stylesheets are SOURCE, not build output, so they live in
# works/site/chrome/ rather than being read back out of the published repo. They
# were restored there from tag pre-quarto-20260731 when the branch removed the
# old pipeline's inputs (2026-07-31).
chrome_dir <- function(root = ".") file.path(root, "site", "chrome")

build_site_chrome <- function(root = ".") {
  slice <- slice_dir

  # Stylesheets and scripts come from the site repo, which is where they live
  # today; site/images/ is the works-side copy rescued on 2026-07-30.
  # Emptied first, not copied into: a file deleted from site/chrome/ otherwise
  # survives in the build and stays published. rmarkdown.js kept being served
  # for exactly that reason after it was retired.
  for (d in c("css", "js")) {
    unlink(file.path(slice, d), recursive = TRUE)
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
  # background-color included: rmarkdown.css sets the body to #fff, which is
  # why the parchment ground from brand.scss never appeared and the site did
  # not match the package sites no matter what the theme said.
  typography <- str_detect(css, 'font-family: "Source Sans Pro"') |
    str_detect(css, "^  color: #404040;") |
    str_detect(css, "^  background-color:#fff;") |
    str_detect(css, "^  line-height: 1.7em;") |
    # The gold #fcbf49 is the old cosmo home-page link colour. It applies to
    # every link inside #homeContent at id specificity, so the bibliography's
    # own colours lost to it silently.
    str_detect(css, "^  color: #fcbf49;")
  write_lines(css[!typography], file.path(slice, "css", "rmarkdown.css"))
  dir.create(file.path(slice, "images"), showWarnings = FALSE)
  file.copy(list.files(file.path(root, "site", "images"), full.names = TRUE),
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
    '---\ntitle: ""\npagetitle: "Alexander Coppock"\n',
    og_front_matter("Alexander Coppock",
                    "Associate Professor of Political Science at Northwestern University. Author of Persuasion in Parallel and a member of the DeclareDesign team.",
                    "images/front_page.png", ""),
    '---\n\n',
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
    '</div>\n',
    # Below the fold: the same published works the gallery shows, as text.
    build_bibliography(root), '\n',
    '</div>\n'
  ), file.path(slice, "index.qmd"))

  # GitHub Pages serves /404.html for any path it cannot resolve on a custom
  # domain. Without one the visitor got GitHub's generic page, with no way back
  # to the site.
  write_lines(str_c(
    '---\ntitle: ""\npagetitle: "Page not found"\n',
    og_front_matter("Page not found | Alexander Coppock",
                    "That page does not exist.",
                    "images/front_page.png", "404.html"),
    '---\n\n',
    '<div class="workProse">\n',
    '<h1>Page not found</h1>\n',
    '<div>That address does not exist. ',
    'Try <a href="published_papers.html">published work</a>, ',
    '<a href="working_papers.html">working papers</a>, ',
    '<a href="software.html">software</a>, ',
    '<a href="notes.html">notes</a>, ',
    'or start from the <a href="index.html">home page</a>.</div>\n',
    '</div>\n'
  ), file.path(slice, "404.qmd"))

  # Notes stays hand-curated by decision: generating it from a directory would
  # publish whatever sits in subpages/, which is precisely the judgement Alex
  # keeps making by hand. What changed (2026-07-31) is only its PRESENTATION:
  # cards like the galleries, rather than a bare list of links. The thumbnail
  # for a PDF note is its first page; for the one HTML note it is a screenshot
  # of the page itself.
  dir.create(file.path(slice, "note_thumbs"), showWarnings = FALSE)
  file.copy(list.files(file.path(root, "site", "notes", "thumbs"), full.names = TRUE),
            file.path(slice, "note_thumbs"), overwrite = TRUE)

  notes <- tribble(
    ~href, ~thumb, ~title, ~extra,
    "note_Random_Assignment_Subject_To_Constraints.pdf",
      "note_Random_Assignment_Subject_To_Constraints.png",
      "Random assignment subject to constraints", "",
    "counterfactual_format.html", "counterfactual_format.png",
      "How to use the counterfactual format",
      " with <a href=\"https://m-graham.com//\">Matt Graham</a>",
    "attention.pdf", "attention.png", "Notes on attention", "",
    "testing_with_grf.pdf", "testing_with_grf.png",
      "Note on testing for heterogeneity with grf",
      " with <a href=\"https://mollyow.github.io/\">Molly Offer-Westort</a>",
    "adjustment.pdf", "adjustment.png", "Trusting covariate adjustment", "",
    # Not a paper, and superseded by the meta-conjoint project (Alex,
    # 2026-07-31). It keeps its URL and becomes a note rather than being
    # retired, because the URL is live and the note still says something.
    "coppock_blyth_2024.pdf", "coppock_blyth_2024.png",
      "A meta-reanalysis of hypothetical candidate conjoint experiments",
      str_c(" with Matthew Blyth",
            "<span class='noteSuperseded'>Superseded by the meta-conjoint project.</span>"),
    "replication_novel_cfp.pdf", "replication_novel_cfp.png",
      "Call for proposals: replication and novel survey experiments",
      str_c(" with <a href=\"https://www.marymcgrath.net/\">Mary McGrath</a>",
            "<span class='noteClosed'>Submissions are closed.</span>"),
    # One note, not two. randomizr_cheatsheet.pdf and
    # coppock_cooper_fultz_2015_cheatsheet.pdf are byte-identical (md5
    # 82bbd8eb...), so listing both would show the same PDF twice. The second
    # URL stays published and unlinked until Alex decides whether to retire it.
    "randomizr_cheatsheet.pdf", "randomizr_cheatsheet.png",
      "randomizr cheatsheet", " with Jasper Cooper and Neal Fultz"
  )

  # Same card-and-description pattern as the papers and software galleries
  # (Alex, 2026-07-31). The description carries the note's title and, where
  # there is one, the coauthor, which is what a gallery caption does elsewhere.
  note_items <- notes |>
    glue_data(
      "<div class='galleryItem'>\n",
      "<a href='{href}'> <img class='galleryItemImage' src='note_thumbs/{thumb}'/> </a>\n",
      "<div class='galleryItemDescription'> <b>{title}</b>{extra} </div>\n",
      "</div>"
    ) |>
    str_flatten("\n")

  write_lines(str_c(
    '---\ntitle: ""\npagetitle: "Notes"\n',
    og_front_matter("Notes | Alexander Coppock",
                    "Teaching notes, syllabi and short methodological pieces by Alexander Coppock.",
                    "images/front_page.png", "notes.html"),
    '---\n\n',
    '<div class="noteGallery">\n<div class="galleryItems">\n',
    note_items,
    '\n</div>\n</div>\n'
  ), file.path(slice_dir, "notes.qmd"))

  invisible(TRUE)
}
