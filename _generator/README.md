# How this site is built

The site is generated from `~/Dropbox/works`, which is the canonical source and
stays in Dropbox. This folder is a copy of the generator so that the code which
produces the site has a history in the same repository as the site itself.

    works/catalog/<work_id>/metadata/work.yaml   the hand-edited layer
    works/catalog/<work_id>/original_materials/  papers, appendices, figures
    works/catalog/<work_id>/assets/              derived images (cards, thumbnails)
    works/bibliography/bibliography.bib          citation fields, BibDesk-managed

Build order:

    source("code/build_slice.R"); source("code/build_galleries.R"); source("code/build_site_chrome.R")
    build_slice("."); build_galleries("."); build_site_chrome(".")
    quarto render quarto_slice
    publish_assets(".")     # flat files, and the URL check against the snapshot

`publish_assets()` verifies the build against `notes/published_urls_20260729.txt`,
the pre-migration URL snapshot. The migration is not finished until every URL in
that file is either present or listed in `notes/retired_urls.txt` with a reason.

Copied here for reference, not run from here: the working copy is in Dropbox.

Only the scripts that build the site are copied here. Other code in
`works/code/` (publication timelines, topic tables, scholar lookups, sketches)
is unrelated to the website and stays in Dropbox.

`publish_assets()` carries a `never_publish` list. It exists because a
copy-everything rule put Alex's own copy of the watermarked book PDF back into
the build on 2026-07-31, the same file that had been purged from this repo's
public history in July at real cost. Anything that must not reach the web goes
on that list rather than being remembered.
