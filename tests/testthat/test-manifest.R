test_that("the sidebar is data, with base-less links and no internal topics", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  sidebar <- sd_sidebar(pkg, fake_routes())

  labels <- vapply(sidebar, function(x) x$label, character(1))
  expect_identical(labels[[1L]], "Overview")
  expect_true("Reference" %in% labels)

  reference <- sidebar[[which(labels == "Reference")]]$items
  links <- vapply(reference, function(x) x$link, character(1))
  expect_identical(links[[1L]], "/reference/")
  expect_true("/reference/add_one/" %in% links)
  # Internal topics have pages so links resolve, but are not advertised.
  expect_false("/reference/secret/" %in% links)
  # Base-less: Starlight applies the base itself.
  expect_false(any(grepl("^/testpkg.full/", links)))
})

test_that("apostrophes in sidebar labels need no escaping", {
  # This is the bug class that killed the old generated-JavaScript sidebar.
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  routes <- c(
    fake_routes(),
    list(list(
      name = "quotes", slug = "quotes", kind = "reference",
      title = "Find one's bearings", route = "/reference/quotes/",
      file = "reference/quotes.md", aliases = "quotes", internal = FALSE
    ))
  )
  sidebar <- sd_sidebar(pkg, routes)
  path <- withr::local_tempfile(fileext = ".json")
  jsonlite::write_json(sidebar, path, auto_unbox = TRUE)

  round_tripped <- jsonlite::read_json(path)
  labels <- unlist(lapply(round_tripped, function(g) {
    if (is.null(g$items)) g$label else vapply(g$items, function(i) i$label, character(1))
  }))
  expect_true("quotes" %in% labels)
})

test_that("the manifest splits the site URL into origin and base", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  manifest <- sd_manifest(pkg, fake_routes())

  expect_identical(manifest$schemaVersion, 1L)
  expect_identical(manifest$site$url, "https://testuser.github.io")
  expect_identical(manifest$site$base, "/testpkg.full")
  # A path in `url` would be counted twice once Astro composes them.
  expect_no_match(manifest$site$url, "testpkg.full", fixed = TRUE)
  expect_identical(manifest$package$urls$homepage, "https://testuser.github.io/testpkg.full/")
})

test_that("install snippets are only offered where they would work", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  manifest <- sd_manifest(pkg, fake_routes())

  # DESCRIPTION names no CRAN or R-universe URL, so neither is claimed.
  expect_null(manifest$install$cran)
  expect_null(manifest$install$runiverse)
  expect_identical(manifest$install$github, "pak::pak(\"testuser/testpkg.full\")")
})

test_that("the topics map is keyed by name and carries aliases", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  manifest <- sd_manifest(pkg, fake_routes())

  expect_true("add_one" %in% names(manifest$topics))
  expect_identical(manifest$topics$add_one$route, "/reference/add_one/")
  expect_identical(unlist(manifest$topics$add_one$aliases), c("add_one", "add1"))
  # Internal topics stay in the map: see-also links to them must resolve.
  expect_true("secret" %in% names(manifest$topics))
})

test_that("redirects cover every old pkgdown URL", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.full"))
  manifest <- sd_manifest(pkg, fake_routes())

  expect_identical(manifest$redirects[["/reference/add_one.html"]], "/reference/add_one/")
  expect_identical(manifest$redirects[["/articles/intro.html"]], "/articles/intro/")
  expect_identical(manifest$redirects[["/index.html"]], "/")
  expect_identical(manifest$redirects[["/reference/index.html"]], "/reference/")
  # Sorted, so the manifest is byte-stable across builds.
  expect_identical(names(manifest$redirects), sort(names(manifest$redirects)))
})

test_that("the manifest is stable", {
  skip_if_no_quarto()
  built <- built_site()
  path <- file.path(built$site, ".starlightdown", "site.json")

  expect_snapshot(
    cat(readLines(path, warn = FALSE, encoding = "UTF-8"), sep = "\n"),
    transform = function(lines) {
      # Only the generator's own version moves with the R package; the
      # documented package's version is signal and stays.
      i <- grep('"name": "starlightdown"', lines, fixed = TRUE)
      if (length(i)) {
        lines[i + 1L] <- sub('"version": "[^"]*"', '"version": "<version>"', lines[i + 1L])
      }
      lines
    }
  )
})
