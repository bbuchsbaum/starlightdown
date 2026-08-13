test_that("migration reads _pkgdown.yml and changes nothing in it", {
  pkg <- local_fixture_pkg("testpkg.full")
  config <- file.path(pkg, "_pkgdown.yml")
  before <- readLines(config, warn = FALSE)

  results <- migrate_from_pkgdown(path = pkg, quiet = TRUE)

  # The configuration stays canonical: it is read, never rewritten.
  expect_identical(readLines(config, warn = FALSE), before)
  expect_identical(basename(results$config), "_pkgdown.yml")
  expect_true(results$scaffolded)
  expect_true(dir.exists(file.path(pkg, "starlight")))
})

test_that("migration reports what carries over", {
  pkg <- local_fixture_pkg("testpkg.full")
  results <- migrate_from_pkgdown(path = pkg, quiet = TRUE)

  expect_match(paste(results$carried, collapse = "\n"), "reference", fixed = TRUE)
  expect_match(paste(results$carried, collapse = "\n"), "articles", fixed = TRUE)
  expect_length(results$manual, 0L)
})

test_that("migration names the pkgdown settings that have no equivalent", {
  pkg <- local_fixture_pkg("testpkg.full")
  writeLines(c(
    "url: https://example.com/pkg",
    "navbar:",
    "  structure:",
    "    right: [github, search]",
    "  components:",
    "    articles:",
    "      text: Articles",
    "template:",
    "  package: mycustomtheme",
    "  includes:",
    "    in_header: <script>analytics()</script>",
    "  bootstrap: 5",
    "development:",
    "  mode: devel",
    "footer:",
    "  structure:",
    "    left: developed_by"
  ), file.path(pkg, "_pkgdown.yml"))

  results <- migrate_from_pkgdown(path = pkg, quiet = TRUE)
  manual <- paste(results$manual, collapse = "\n")

  expect_match(manual, "Navbar components", fixed = TRUE)
  expect_match(manual, "Right-side navbar", fixed = TRUE)
  expect_match(manual, "mycustomtheme", fixed = TRUE)
  expect_match(manual, "Custom HTML includes", fixed = TRUE)
  expect_match(manual, "Bootstrap", fixed = TRUE)
  expect_match(manual, "development", fixed = TRUE)
  expect_match(manual, "Footer", fixed = TRUE)

  expect_match(paste(results$carried, collapse = "\n"), "url", fixed = TRUE)
})

test_that("a package with no _pkgdown.yml migrates to nothing, successfully", {
  pkg <- local_fixture_pkg("testpkg.minimal")
  results <- migrate_from_pkgdown(path = pkg, quiet = TRUE)

  expect_null(results$config)
  expect_length(results$carried, 0L)
  expect_length(results$manual, 0L)
  expect_true(dir.exists(file.path(pkg, "starlight")))
})

test_that("migration prints a report naming both halves", {
  pkg <- local_fixture_pkg("testpkg.full")
  writeLines(c("template:", "  package: mycustomtheme"), file.path(pkg, "_pkgdown.yml"))

  expect_message(migrate_from_pkgdown(path = pkg), "Needs your attention")
  expect_message(migrate_from_pkgdown(path = pkg), "mycustomtheme")
})

test_that("migration does not scaffold when asked not to", {
  pkg <- local_fixture_pkg("testpkg.minimal")
  results <- migrate_from_pkgdown(path = pkg, scaffold = FALSE, quiet = TRUE)

  expect_false(results$scaffolded)
  expect_false(dir.exists(file.path(pkg, "starlight")))
})

test_that("an unparseable _pkgdown.yml warns instead of aborting", {
  pkg <- local_fixture_pkg("testpkg.minimal")
  writeLines(c("reference:", "  - title: [unclosed"), file.path(pkg, "_pkgdown.yml"))

  expect_warning(
    results <- migrate_from_pkgdown(path = pkg, quiet = TRUE),
    "Could not parse"
  )
  expect_length(results$manual, 0L)
})

test_that("migration errors without a DESCRIPTION", {
  expect_error(migrate_from_pkgdown(path = withr::local_tempdir()), "DESCRIPTION")
})
