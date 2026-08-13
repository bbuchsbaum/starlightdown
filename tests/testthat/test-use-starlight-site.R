test_that("use_starlight_site() scaffolds a buildable project", {
  pkg <- local_fixture_pkg()
  site <- use_starlight_site(path = pkg, npm_install = FALSE)

  expect_true(dir.exists(site))
  expect_true(file.exists(file.path(site, "astro.config.mjs")))
  expect_true(file.exists(file.path(site, "ec.config.mjs")))
  expect_true(file.exists(file.path(site, "package.json")))
  expect_true(file.exists(file.path(site, "src", "content.config.ts")))

  astro <- readLines(file.path(site, "astro.config.mjs"), warn = FALSE)
  expect_false(any(grepl("PKG_TITLE", astro, fixed = TRUE)))

  buildignore <- readLines(file.path(pkg, ".Rbuildignore"), warn = FALSE)
  expect_true("^starlight$" %in% buildignore)
})

test_that("the scaffold vendors the plugin before npm could need it", {
  pkg <- local_fixture_pkg()
  site <- use_starlight_site(path = pkg, npm_install = FALSE)

  # package.json points npm at this path; it has to exist first.
  expect_true(file.exists(file.path(site, ".starlightdown", "plugin", "index.mjs")))
  expect_true(file.exists(file.path(site, ".starlightdown", "plugin", "schema.mjs")))
  expect_true(file.exists(file.path(site, ".starlightdown", "config.mjs")))
  expect_true(file.exists(file.path(site, ".starlightdown", "template-version")))

  plugin <- jsonlite::read_json(file.path(site, ".starlightdown", "plugin", "package.json"))
  expect_identical(plugin$name, "starlightdown-starlight")
  expect_identical(plugin$version, as.character(utils::packageVersion("starlightdown")))
})

test_that("the scaffold pins the versions the frontend was built against", {
  pkg <- local_fixture_pkg()
  site <- use_starlight_site(path = pkg, npm_install = FALSE)
  pkgjson <- jsonlite::read_json(file.path(site, "package.json"))

  # Starlight 0.41.7 peers on astro ^7.0.2; astro 5 cannot run this frontend.
  expect_identical(pkgjson$dependencies$`@astrojs/starlight`, "0.41.7")
  expect_identical(pkgjson$dependencies$astro, "7.2.1")
  expect_identical(pkgjson$dependencies$sharp, "0.35.3")
  expect_identical(
    pkgjson$dependencies$`starlightdown-starlight`,
    "file:./.starlightdown/plugin"
  )
  expect_no_match(pkgjson$name, "PKG_SLUG", fixed = TRUE)
  expect_match(pkgjson$name, "testpkg.minimal", fixed = TRUE)
})

test_that("the scaffold ships a lockfile, so CI can run npm ci immediately", {
  # Without a committed lockfile, `npm ci` fails and the bundled workflow
  # cannot build a freshly scaffolded site (CONTRACT.md section 1).
  pkg <- local_fixture_pkg()
  site <- use_starlight_site(path = pkg, npm_install = FALSE)

  lock_path <- file.path(site, "package-lock.json")
  expect_true(file.exists(lock_path))

  lock <- jsonlite::read_json(lock_path)
  expect_identical(lock$lockfileVersion, 3L)
  expect_identical(lock$name, "testpkg.minimal-docs")

  # The plugin is linked by path, not pinned by version, so stamping the
  # plugin with a new starlightdown version never desynchronises the lockfile.
  plugin <- lock$packages$`node_modules/starlightdown-starlight`
  expect_true(isTRUE(plugin$link))
  expect_identical(plugin$resolved, ".starlightdown/plugin")

  # Every dependency the scaffold pins must be resolved in the lockfile.
  pkgjson <- jsonlite::read_json(file.path(site, "package.json"))
  for (dep in names(pkgjson$dependencies)) {
    expect_true(
      !is.null(lock$packages[[paste0("node_modules/", dep)]]),
      info = paste0(dep, " is missing from package-lock.json")
    )
  }
})

test_that("use_starlight_site() refuses to overwrite without overwrite = TRUE", {
  pkg <- local_fixture_pkg()
  use_starlight_site(path = pkg, npm_install = FALSE)

  expect_error(use_starlight_site(path = pkg, npm_install = FALSE), "already exists")
  expect_no_error(
    use_starlight_site(path = pkg, overwrite = TRUE, npm_install = FALSE)
  )
})

test_that("use_starlight_site() errors without a DESCRIPTION", {
  dir <- withr::local_tempdir()
  expect_error(use_starlight_site(path = dir), "DESCRIPTION")
})

test_that("Quarto is located from the environment, the PATH, or RStudio", {
  withr::local_envvar(c(QUARTO_PATH = ""))
  found <- sd_quarto_bin()
  # Either a real binary or NA; never an empty string, which would look usable.
  expect_true(is.na(found) || nzchar(found))

  fake <- withr::local_tempfile(fileext = ".sh")
  writeLines("#!/bin/sh", fake)
  withr::local_envvar(c(QUARTO_PATH = fake))
  expect_identical(sd_quarto_bin(), fake)
})

test_that("building articles without Quarto fails with an actionable message", {
  expect_error(sd_require_quarto(NA_character_), "Quarto is required")
  expect_error(sd_require_quarto(NA_character_), "articles = FALSE")
})
