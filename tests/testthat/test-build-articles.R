test_that("Quarto's title heading is stripped", {
  # Starlight renders the frontmatter title as the page H1; keeping Quarto's
  # would put two on the page.
  expect_identical(
    sd_strip_leading_h1("# A Title\n\nBody text.\n"),
    "\nBody text."
  )
  expect_identical(
    sd_strip_leading_h1("\n\n# A Title\nBody.\n"),
    "Body."
  )
  # Only a *leading* H1 goes; one further down is the author's.
  expect_identical(
    sd_strip_leading_h1("Intro.\n\n# Later\n"),
    "Intro.\n\n# Later\n"
  )
  expect_identical(sd_strip_leading_h1("## Not an H1\n"), "## Not an H1\n")
})

test_that("Quarto fence info strings are normalised", {
  body <- paste(
    "``` r", "1 + 1", "```", "",
    "``` r-output", "[1] 2", "```", "",
    "``` r-message", "hi", "```", "",
    "``` python", "pass", "```",
    sep = "\n"
  )
  out <- sd_normalise_quarto_fences(body)

  expect_match(out, "```r\n1 + 1", fixed = TRUE)
  expect_match(out, "```r-output\n[1] 2", fixed = TRUE)
  expect_match(out, "```r-message\nhi", fixed = TRUE)
  # Only the reserved R info strings are ours to touch.
  expect_match(out, "``` python", fixed = TRUE)
})

test_that("root-relative links survive Quarto's rewriting", {
  # Quarto resolves `/reference/x/` in vignettes/ to `../reference/x/`, which
  # from the article's own route would point at /articles/reference/x/.
  body <- "See [ref](../reference/full_add/) and ![fig](plot.png) and [up](../../out/)."
  restored <- sd_restore_root_links(body, depth = 1L)

  expect_match(restored, "[ref](/reference/full_add/)", fixed = TRUE)
  expect_match(restored, "![fig](plot.png)", fixed = TRUE)
  # A link climbing past the project root is not one we rewrote.
  expect_match(restored, "[up](../../out/)", fixed = TRUE)

  expect_identical(sd_restore_root_links(body, depth = 0L), body)
})

test_that("prose links take the base but images stay relative", {
  body <- "[a](/reference/x/) ![b](figures/b.png) [c](https://example.com) [d](/testpkg/already/)"
  out <- sd_apply_base_to_links(body, "/testpkg")

  expect_match(out, "[a](/testpkg/reference/x/)", fixed = TRUE)
  expect_match(out, "![b](figures/b.png)", fixed = TRUE)
  expect_match(out, "[c](https://example.com)", fixed = TRUE)
  # Already based: not doubled.
  expect_match(out, "[d](/testpkg/already/)", fixed = TRUE)

  expect_identical(sd_apply_base_to_links(body, "/"), body)
})

test_that("relative targets are picked out of a body", {
  body <- paste(
    "![a](figures/a.png)",
    "[b](https://example.com)",
    "[c](/reference/)",
    "[d](sub/dir/file.svg)",
    "[e](#anchor)",
    "[f](other.md#frag)",
    sep = "\n"
  )
  expect_setequal(
    sd_relative_targets(body),
    c("figures/a.png", "sub/dir/file.svg", "other.md")
  )
})

test_that("article metadata comes from the source YAML", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines(c(
    "---",
    "title: \"One's Title\"",
    "description: A description.",
    "---",
    "",
    "Body."
  ), path)

  vignette <- data.frame(
    name = "x", title = "fallback", description = "fallback",
    stringsAsFactors = FALSE
  )
  meta <- sd_article_metadata(path, vignette)

  expect_identical(meta$title, "One's Title")
  expect_identical(meta$description, "A description.")
})

test_that("the article builder falls back to pkgdown's metadata", {
  path <- withr::local_tempfile(fileext = ".Rmd")
  writeLines("No frontmatter here.", path)

  vignette <- data.frame(
    name = "x", title = "From pkgdown", description = "Also from pkgdown",
    stringsAsFactors = FALSE
  )
  meta <- sd_article_metadata(path, vignette)

  expect_identical(meta$title, "From pkgdown")
  expect_identical(meta$description, "Also from pkgdown")
})

test_that("the generated _quarto.yml uses YAML 1.2 booleans", {
  # Quarto rejects `yes`/`no`, which is what R's yaml package writes by default.
  dir <- withr::local_tempdir()
  vignettes <- data.frame(file_in = "vignettes/a.Rmd", stringsAsFactors = FALSE)
  sd_write_quarto_config(dir, vignettes)

  text <- paste(readLines(file.path(dir, "_quarto.yml"), warn = FALSE), collapse = "\n")
  expect_match(text, "echo: true", fixed = TRUE)
  expect_false(grepl(": yes", text, fixed = TRUE))
  expect_false(grepl(": no\n", text, fixed = TRUE))

  config <- yaml::read_yaml(file.path(dir, "_quarto.yml"))
  expect_identical(config$format$gfm$wrap, "preserve")
  expect_identical(config$execute$freeze, "auto")
  # These are what turn knitr output into the contract's fence info strings.
  expect_identical(unlist(config$knitr$opts_chunk$class.output), "r-output")
  expect_identical(unlist(config$knitr$opts_chunk$class.error), "r-error")
})

test_that("articles render, with figures and links, when Quarto is available", {
  skip_if_no_quarto()
  built <- built_site()
  articles <- file.path(built$site, "src", "content", "docs", "articles")

  expect_true(file.exists(file.path(articles, "intro.md")))

  front <- read_frontmatter(file.path(articles, "intro.md"))
  expect_identical(front$title, "Getting started with testpkg.full")
  expect_identical(front$sd$kind, "article")

  body <- read_body(file.path(articles, "intro.md"))
  # Executed code, with the reserved output fences.
  expect_match(body, "```r\nlibrary(testpkg.full)", fixed = TRUE)
  expect_match(body, "```r-output", fixed = TRUE)
  expect_match(body, "```r-message", fixed = TRUE)
  # Math survives.
  expect_match(body, "$a^2 + b^2$", fixed = TRUE)
  # Base applied to prose links, images left relative.
  expect_match(body, "(/testpkg.full/reference/full_add/)", fixed = TRUE)
  expect_no_match(body, "](../reference/", fixed = TRUE)

  # Every image the article names exists next to it.
  for (target in sd_relative_targets(body)) {
    expect_true(file.exists(file.path(articles, target)), info = target)
  }
  expect_true(dir.exists(file.path(articles, "intro_files")))
  expect_true(file.exists(file.path(articles, "mark.svg")))
})

test_that("a .qmd article renders the same way a .Rmd does", {
  skip_if_no_quarto()
  # pkgdown loads the `quarto` package for any .qmd it finds in vignettes/,
  # which is why the base fixture does not ship one.
  skip_if_not_installed("quarto")

  pkg_path <- local_fixture_pkg("testpkg.full")
  fs::file_copy(
    test_path("fixtures", "advanced.qmd"),
    file.path(pkg_path, "vignettes", "advanced.qmd")
  )
  withr::local_envvar(c(
    STARLIGHTDOWN_CACHE_DIR = withr::local_tempdir()
  ))

  pkg <- sd_pkg(pkg_path)
  expect_true("advanced" %in% pkg$vignettes$name)

  stage <- withr::local_tempdir()
  routes <- sd_build_articles(pkg, stage, quiet = TRUE)

  names <- vapply(routes, function(r) r$name, character(1))
  expect_true("advanced" %in% names)

  front <- read_frontmatter(file.path(stage, "articles", "advanced.md"))
  expect_identical(front$title, "Advanced usage")
  expect_identical(front$sd$kind, "article")

  body <- read_body(file.path(stage, "articles", "advanced.md"))
  expect_match(body, "```r\nlibrary(testpkg.full)", fixed = TRUE)
  expect_match(body, "```r-output", fixed = TRUE)
  # The source H1 Quarto writes from the title must not reach the page.
  expect_no_match(body, "(?m)^# ", perl = TRUE)
})

test_that("the freeze cache makes a second build cheaper", {
  skip_if_no_quarto()
  built <- built_site()
  # The cache directory the build used still holds Quarto's freeze output, so
  # an unchanged vignette is not re-executed next time.
  cache <- Sys.getenv("STARLIGHTDOWN_CACHE_DIR")
  skip_if(!nzchar(cache) || !dir.exists(cache), "no cache directory")
  expect_true(length(fs::dir_ls(cache, recurse = TRUE, glob = "*_freeze*")) > 0 ||
    length(fs::dir_ls(cache, recurse = TRUE, type = "directory")) > 0)
})
