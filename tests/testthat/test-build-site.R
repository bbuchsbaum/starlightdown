test_that("build_site() errors without a DESCRIPTION", {
  dir <- withr::local_tempdir()
  expect_error(build_site(path = dir), "DESCRIPTION")
})

test_that("build_site() errors when the site has not been scaffolded", {
  pkg <- local_fixture_pkg()
  expect_error(build_site(path = pkg), "use_starlight_site")
})

test_that("build_site() builds a reference-only site without Quarto", {
  # A package with no vignettes must not need Quarto at all.
  pkg <- local_fixture_pkg("testpkg.minimal")
  use_starlight_site(path = pkg, npm_install = FALSE)

  # No URL anywhere in DESCRIPTION, so the build says so and carries on.
  expect_warning(
    build_site(path = pkg, quiet = TRUE, examples = FALSE),
    "No documentation URL"
  )

  docs <- file.path(pkg, "starlight", "src", "content", "docs")
  expect_true(file.exists(file.path(docs, "index.md")))
  expect_true(file.exists(file.path(docs, "reference", "index.md")))
  expect_true(file.exists(file.path(docs, "reference", "add_one.md")))
  expect_false(dir.exists(file.path(docs, "articles")))

  manifest <- read_manifest(file.path(pkg, "starlight"))
  expect_identical(manifest$schemaVersion, 1L)
  # No URL in DESCRIPTION, so the site is deployed at a root.
  expect_null(manifest$site$url)
  expect_identical(manifest$site$base, "/")
})

test_that("build_site() produces every route and its redirect", {
  skip_if_no_quarto()
  built <- built_site()
  docs <- file.path(built$site, "src", "content", "docs")
  public <- file.path(built$site, "public")

  expect_true(file.exists(file.path(docs, "index.md")))
  expect_true(file.exists(file.path(docs, "news.md")))
  expect_true(file.exists(file.path(docs, "articles", "intro.md")))
  expect_true(file.exists(file.path(docs, "reference", "index.md")))

  # Old pkgdown URLs get a stub, except where one would overwrite a page.
  expect_true(file.exists(file.path(public, "reference", "full_add.html")))
  expect_true(file.exists(file.path(public, "articles", "intro.html")))
  expect_false(file.exists(file.path(public, "reference", "index.html")))
  expect_false(file.exists(file.path(public, "news", "index.html")))
  expect_false(file.exists(file.path(public, "index.html")))
})

test_that("build_site() writes the machine-owned directory and nothing else", {
  skip_if_no_quarto()
  built <- built_site()
  machine <- file.path(built$site, ".starlightdown")

  expect_setequal(
    basename(fs::dir_ls(machine)),
    c("plugin", "site.json", "config.mjs", "template-version")
  )
  # The generated config reads the manifest at runtime (CONTRACT.md §3).
  config <- paste(readLines(file.path(machine, "config.mjs"), warn = FALSE), collapse = "\n")
  expect_match(config, "readFileSync(new URL('./site.json'", fixed = TRUE)
  expect_match(
    config,
    "plugins: [starlightdown({ manifest, theme: manifest.site.theme })]",
    fixed = TRUE
  )

  # The vendored plugin is stamped with the R package's version.
  plugin <- jsonlite::read_json(file.path(machine, "plugin", "package.json"))
  expect_identical(plugin$version, as.character(utils::packageVersion("starlightdown")))
  expect_identical(plugin$name, "starlightdown-starlight")
})

test_that("a second build is byte-identical", {
  skip_if_no_quarto()
  built <- built_site()
  docs <- file.path(built$site, "src", "content", "docs")

  digest <- function(dir) {
    files <- sort(as.character(fs::dir_ls(dir, recurse = TRUE, type = "file")))
    stats::setNames(
      vapply(files, function(f) unname(tools::md5sum(f)), character(1)),
      as.character(fs::path_rel(files, dir))
    )
  }
  before <- digest(docs)
  manifest_before <- readLines(
    file.path(built$site, ".starlightdown", "site.json"),
    warn = FALSE
  )

  build_site(path = built$pkg_path, quiet = TRUE)

  after <- digest(docs)
  expect_identical(names(before), names(after))
  expect_identical(unname(before), unname(after))
  expect_identical(
    readLines(file.path(built$site, ".starlightdown", "site.json"), warn = FALSE),
    manifest_before
  )
})

test_that("a failing build leaves the live site untouched", {
  skip_if_no_quarto()
  built <- built_site()
  docs <- file.path(built$site, "src", "content", "docs")

  before <- sort(as.character(fs::path_rel(
    fs::dir_ls(docs, recurse = TRUE, type = "file"), docs
  )))
  home_before <- readLines(file.path(docs, "index.md"), warn = FALSE)

  # Point the README at an image that does not exist. The validation gate must
  # catch it and refuse to commit.
  readme <- file.path(built$pkg_path, "README.md")
  original <- readLines(readme, warn = FALSE)
  withr::defer(writeLines(original, readme))
  writeLines(c(original, "", "![missing](man/figures/not-here.png)"), readme)

  expect_error(build_site(path = built$pkg_path, quiet = TRUE), "validation check")

  after <- sort(as.character(fs::path_rel(
    fs::dir_ls(docs, recurse = TRUE, type = "file"), docs
  )))
  expect_identical(before, after)
  expect_identical(readLines(file.path(docs, "index.md"), warn = FALSE), home_before)

  # Restore, so the cached site is usable by later tests.
  writeLines(original, readme)
  build_site(path = built$pkg_path, quiet = TRUE)
})
