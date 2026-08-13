# Home -----------------------------------------------------------------------

test_that("the README becomes index.md with its H1 removed", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  stage <- withr::local_tempdir()

  route <- sd_build_home(pkg, stage)
  front <- read_frontmatter(file.path(stage, "index.md"))
  body <- read_body(file.path(stage, "index.md"))

  # Title and description come from DESCRIPTION, not from the README.
  expect_identical(front$title, "A Full-Featured Test Package for 'starlightdown'")
  expect_match(front$description, "^A fixture package")
  expect_identical(front$sd$kind, "home")

  # The README's own `# testpkg.full` would be a second H1 on the page.
  expect_no_match(body, "(?m)^# ", perl = TRUE)
  expect_identical(route$route, "/")
  expect_identical(route$file, "index.md")
})

test_that("README badges become structured frontmatter", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  stage <- withr::local_tempdir()
  sd_build_home(pkg, stage)

  front <- read_frontmatter(file.path(stage, "index.md"))
  body <- read_body(file.path(stage, "index.md"))

  expect_length(front$sd$badges, 2L)
  expect_identical(front$sd$badges[[1L]]$text, "CRAN status")
  expect_identical(
    front$sd$badges[[1L]]$href,
    "https://cran.r-project.org/package=testpkg.full"
  )
  # Having become data, they are no longer a wall of images in the prose.
  expect_no_match(body, "r-pkg.org/badges", fixed = TRUE)
})

test_that("man/figures images are copied next to the home page", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  stage <- withr::local_tempdir()
  route <- sd_build_home(pkg, stage)

  body <- read_body(file.path(stage, "index.md"))
  expect_match(body, "](figures/mark.svg)", fixed = TRUE)
  expect_no_match(body, "man/figures/", fixed = TRUE)
  expect_true(file.exists(file.path(stage, "figures", "mark.svg")))
  expect_identical(route$assets, "figures/mark.svg")
})

test_that("a package with no README still gets an index page", {
  pkg_path <- local_fixture_pkg("testpkg.minimal")
  file.remove(file.path(pkg_path, "README.md"))
  pkg <- sd_pkg(pkg_path)
  stage <- withr::local_tempdir()

  route <- sd_build_home(pkg, stage)
  front <- read_frontmatter(file.path(stage, "index.md"))

  expect_identical(front$title, "A Minimal Test Package for 'starlightdown'")
  expect_identical(route$kind, "home")
})

test_that("badge extraction only takes a leading run", {
  body <- paste(
    "[![One](img1)](href1) [![Two](img2)](href2)",
    "",
    "Prose.",
    "",
    "[![Three](img3)](href3)",
    sep = "\n"
  )
  out <- sd_extract_badges(body)

  expect_length(out$badges, 2L)
  expect_identical(vapply(out$badges, function(b) b$text, character(1)), c("One", "Two"))
  # A badge used as illustration mid-document stays in the prose.
  expect_match(out$body, "[![Three](img3)](href3)", fixed = TRUE)
})

# News -----------------------------------------------------------------------

test_that("NEWS.md becomes news.md with every heading demoted", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  stage <- withr::local_tempdir()

  news <- sd_build_news(pkg, stage)
  front <- read_frontmatter(file.path(stage, "news.md"))
  body <- read_body(file.path(stage, "news.md"))

  expect_identical(front$title, "Changelog")
  expect_identical(front$sd$kind, "news")

  # Releases were H1 in the source; they must not be H1 on the page.
  expect_no_match(body, "(?m)^# ", perl = TRUE)
  expect_match(body, "## testpkg.full 0.2.1 <time", fixed = TRUE)
  expect_match(body, "### Bug fixes", fixed = TRUE)

  expect_identical(news$latest, "0.2.1")
  expect_identical(
    vapply(news$versions, function(v) v$version, character(1)),
    c("0.2.1", "0.2.0")
  )
  # The date is part of the heading text, so it is part of the anchor too.
  expect_identical(news$versions[[1L]]$anchor, "testpkgfull-021-2026-08-13")
})

test_that("heading demotion leaves code blocks alone", {
  lines <- c("# Release", "", "```r", "# a comment, not a heading", "x <- 1", "```", "", "## Section")
  out <- sd_demote_headings(lines)

  expect_identical(out[[1L]], "## Release")
  expect_identical(out[[4L]], "# a comment, not a heading")
  expect_identical(out[[8L]], "### Section")
})

test_that("versions are read from a variety of heading styles", {
  expect_identical(sd_extract_version("testpkg 1.2.3"), "1.2.3")
  expect_identical(sd_extract_version("1.2.3"), "1.2.3")
  expect_identical(sd_extract_version("pkg v0.1.0-9000"), "0.1.0-9000")
  expect_identical(sd_extract_version("Unreleased"), "Unreleased")
})

test_that("a package with no NEWS produces no news page", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  stage <- withr::local_tempdir()

  expect_null(sd_build_news(pkg, stage))
  expect_false(file.exists(file.path(stage, "news.md")))
})

# Citation -------------------------------------------------------------------

test_that("inst/CITATION supplies the citation block", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  citation <- sd_build_citation(pkg)

  expect_named(citation, c("text", "bibtex"))
  expect_match(citation$text, "testpkg.full", fixed = TRUE)
  expect_match(citation$bibtex, "@Manual{", fixed = TRUE)
  expect_match(citation$bibtex, "R package version 0.2.1", fixed = TRUE)
  # Wrapping would otherwise depend on the console width of the build machine.
  expect_no_match(citation$text, "\n[^\n]", perl = TRUE)
})

test_that("a package without CITATION still gets one from DESCRIPTION", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  citation <- sd_build_citation(pkg)

  expect_match(citation$text, "testpkg.minimal", fixed = TRUE)
  expect_match(citation$bibtex, "@Manual{", fixed = TRUE)
})
