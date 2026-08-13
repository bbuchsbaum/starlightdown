# One test per finding from the Phase 3/4 adversarial review.

test_that("a package with no documentation URL omits site.url entirely", {
  # A JSON null arrives in Astro as an object and aborts the build; the key has
  # to be absent. base alone is legal.
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  manifest <- sd_manifest(pkg, fake_routes())

  expect_false("url" %in% names(manifest$site))
  expect_identical(manifest$site$base, "/")

  path <- withr::local_tempfile(fileext = ".json")
  sd_write_manifest(manifest, path)
  expect_false(grepl('"url"', paste(readLines(path, warn = FALSE), collapse = "")))

  machine <- withr::local_tempdir()
  sd_write_astro_config(machine, "default")
  expect_match(sd_read_utf8(file.path(machine, "config.mjs")), "?? undefined", fixed = TRUE)
})

test_that("a redirect source can never escape public/", {
  # These reach fs::file_delete on the next build, so they must never become
  # a path at all.
  expect_true(is.na(sd_redirect_output_path("/../../keepme.txt")))
  expect_true(is.na(sd_redirect_output_path("/../src/styles/custom.css")))
  expect_true(is.na(sd_redirect_output_path("/a/../../b.html")))
  expect_true(is.na(sd_redirect_output_path("\\\\server\\share\\x.html")))
  expect_true(is.na(sd_redirect_output_path("C:/windows/x.html")))
  expect_true(is.na(sd_redirect_output_path("https://example.com/x.html")))
  expect_true(is.na(sd_redirect_output_path("/")))

  expect_identical(sd_redirect_output_path("/reference/x.html"), "reference/x.html")
  expect_identical(sd_redirect_output_path("/a/b/../c.html"), "a/c.html")
})

test_that("an escaping redirect is refused, and nothing outside public/ is touched", {
  site <- withr::local_tempdir()
  public <- file.path(site, "public")
  fs::dir_create(public)
  keep <- file.path(site, "keepme.txt")
  writeLines("precious", keep)

  routes <- list(list(route = "/", kind = "home"))
  expect_warning(
    result <- sd_write_redirects(
      list("/../keepme.txt" = "/", "/ok.html" = "/"),
      routes, public, fake_pkg()
    ),
    "does not name a path inside the site"
  )

  expect_true(file.exists(keep))
  expect_identical(result$written, "/ok.html")
  expect_true("/../keepme.txt" %in% result$skipped)

  # And the deletion path refuses it too, even if it somehow got recorded.
  stage <- sd_new_stage(site)
  sd_commit_public(stage$public, public, previous = "../keepme.txt")
  expect_true(file.exists(keep))
})

test_that("the stub inventory lives beside the stubs, not in the manifest", {
  # public/ is committed and .starlightdown/ is not, so in CI the manifest is
  # absent and stale stubs would never be cleaned.
  public <- withr::local_tempdir()
  routes <- list(list(route = "/reference/x/", kind = "reference"))
  sd_write_redirects(list("/reference/x.html" = "/reference/x/"), routes, public, fake_pkg())

  expect_true(file.exists(file.path(public, ".starlightdown-redirects.json")))
  expect_identical(sd_read_stub_inventory(public), "reference/x.html")
  expect_identical(sd_read_stub_inventory(withr::local_tempdir()), character())
})

test_that("public/ pruning only removes directories our own removal emptied", {
  site <- withr::local_tempdir()
  live <- file.path(site, "public")
  fs::dir_create(file.path(live, "reference"))
  fs::dir_create(file.path(live, "user-empty-dir"))
  writeLines("stub", file.path(live, "reference", "old.html"))

  stage <- sd_new_stage(site)
  sd_commit_public(stage$public, live, previous = "reference/old.html")

  expect_false(dir.exists(file.path(live, "reference")))
  # Not ours; not our business.
  expect_true(dir.exists(file.path(live, "user-empty-dir")))
})

test_that("concurrent builds get their own staging directory", {
  site <- withr::local_tempdir()
  first <- sd_new_stage(site)
  writeLines("mine", file.path(first$content, "a.md"))

  second <- sd_new_stage(site)
  expect_false(identical(first$root, second$root))
  # The second build must not have deleted the first one's work.
  expect_true(file.exists(file.path(first$content, "a.md")))

  sd_discard_stage(second$root)
  expect_true(file.exists(file.path(first$content, "a.md")))
})

test_that("the cross-volume move fallback replaces rather than merges", {
  root <- withr::local_tempdir()
  from <- file.path(root, "from")
  to <- file.path(root, "to")
  fs::dir_create(from)
  fs::dir_create(to)
  writeLines("new", file.path(from, "new.md"))
  writeLines("stale", file.path(to, "stale.md"))

  # Exercise the fallback directly: rename would not show the merge bug.
  unlink(to, recursive = TRUE)
  fs::dir_copy(from, to)
  expect_setequal(basename(fs::dir_ls(to)), "new.md")
})

test_that("ordering in the manifest does not depend on the locale", {
  words <- c("a_b", "aB", "Ab", "ab", "A.b")
  expect_identical(
    withr::with_collate("C", sort(words, method = "radix")),
    withr::with_collate("en_US.UTF-8", sort(words, method = "radix"))
  )
})

test_that("an index article is served at /articles/", {
  expect_identical(sd_article_route("index"), "/articles/")
  expect_identical(sd_article_route("intro"), "/articles/intro/")
})

test_that("NEWS written with ## releases keeps its version data", {
  expect_identical(sd_news_top_level(c("## pkg 1.0", "", "text")), 2L)
  expect_identical(sd_news_top_level(c("# pkg 1.0", "", "## Fixes")), 1L)
  # A `#` inside a fence is not a heading.
  expect_identical(sd_news_top_level(c("## pkg 1.0", "```r", "# comment", "```")), 2L)

  versions <- sd_news_versions(c("## pkg 1.2.0", "", "### Fixes"), level = 2L)
  expect_length(versions, 1L)
  expect_identical(versions[[1L]]$version, "1.2.0")
})

test_that("a NEWS file already at ## is not demoted further", {
  pkg_path <- local_fixture_pkg("testpkg.full")
  writeLines(
    c("## testpkg.full 0.3.0", "", "- a change", "", "## testpkg.full 0.2.0", "", "- older"),
    file.path(pkg_path, "NEWS.md")
  )
  pkg <- sd_pkg(pkg_path)
  stage <- withr::local_tempdir()

  news <- sd_build_news(pkg, stage)
  body <- read_body(file.path(stage, "news.md"))

  expect_identical(news$latest, "0.3.0")
  expect_match(body, "## testpkg.full 0.3.0", fixed = TRUE)
  expect_no_match(body, "### testpkg.full", fixed = TRUE)
})

test_that("the citation year comes from DESCRIPTION, never the clock", {
  # Otherwise site.json changes on the 1st of January.
  pkg_path <- local_fixture_pkg("testpkg.minimal")
  desc <- readLines(file.path(pkg_path, "DESCRIPTION"), warn = FALSE)
  writeLines(c(desc, "Date: 2024-03-01"), file.path(pkg_path, "DESCRIPTION"))

  pkg <- sd_pkg(pkg_path)
  expect_identical(sd_package_year(pkg), "2024")
  expect_match(sd_build_citation(pkg)$text, "2024", fixed = TRUE)
})

test_that("a package with no date produces a citation without a year", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  expect_null(sd_package_year(pkg))
  citation <- sd_build_citation(pkg)
  expect_match(citation$bibtex, "@Manual{", fixed = TRUE)
  expect_no_match(citation$bibtex, format(Sys.Date(), "%Y"), fixed = TRUE)
})

test_that("a vignette that uses # for its own sections can build", {
  skip_if_no_quarto()
  built <- built_site()
  body <- read_body(file.path(built$site, "src", "content", "docs", "articles", "intro.md"))
  expect_no_match(body, "(?m)^# ", perl = TRUE)
  expect_match(body, "## Adding numbers", fixed = TRUE)
})

test_that("a validation failure names the source file, not the generated one", {
  routes <- list(list(file = "articles/intro.md", source = "vignettes/intro.Rmd"))
  problems <- sd_name_sources("articles/intro.md: relative target 'x' does not exist.", routes)
  expect_match(problems, "articles/intro.md (from vignettes/intro.Rmd):", fixed = TRUE)
})

test_that("the manifest is written after the content is committed", {
  # A manifest describing pages that failed to commit would ship a sidebar
  # full of links to nothing.
  skip_if_no_quarto()
  built <- built_site()
  manifest <- file.path(built$site, ".starlightdown", "site.json")
  docs <- file.path(built$site, "src", "content", "docs")
  expect_true(file.exists(manifest))
  expect_gte(
    file.info(manifest)$mtime,
    max(file.info(fs::dir_ls(docs, recurse = TRUE, type = "file"))$mtime)
  )
})
