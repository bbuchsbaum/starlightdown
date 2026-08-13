# Redirects ------------------------------------------------------------------

test_that("a redirect stub is a meta-refresh page with the base applied", {
  expect_snapshot(cat(sd_redirect_html("/reference/add_one/", fake_pkg())))
})

test_that("a stub without a site URL omits the canonical link", {
  html <- sd_redirect_html("/reference/add_one/", fake_pkg(url = NA_character_))
  expect_no_match(html, "canonical", fixed = TRUE)
  expect_match(html, "url=/testpkg/reference/add_one/", fixed = TRUE)
})

test_that("redirect targets are HTML-escaped", {
  html <- sd_redirect_html("/a&b/\"c\"/", fake_pkg())
  expect_match(html, "&amp;", fixed = TRUE)
  expect_match(html, "&quot;", fixed = TRUE)
  expect_no_match(html, "url=/testpkg/a&b", fixed = TRUE)
})

test_that("a stub is never written where a real page will land", {
  # Under directory output /reference/ is written as reference/index.html, so a
  # stub there would overwrite the page it points at (CONTRACT.md §6).
  routes <- list(
    list(route = "/", kind = "home"),
    list(route = "/reference/", kind = "reference-index"),
    list(route = "/reference/add_one/", kind = "reference")
  )
  redirects <- list(
    "/index.html" = "/",
    "/reference/index.html" = "/reference/",
    "/reference/add_one.html" = "/reference/add_one/"
  )
  public <- withr::local_tempdir()

  result <- sd_write_redirects(redirects, routes, public, fake_pkg())

  expect_setequal(result$skipped, c("/index.html", "/reference/index.html"))
  expect_identical(result$written, "/reference/add_one.html")
  expect_true(file.exists(file.path(public, "reference", "add_one.html")))
  expect_false(file.exists(file.path(public, "index.html")))
  expect_false(file.exists(file.path(public, "reference", "index.html")))
})

# Staging and commit ---------------------------------------------------------

test_that("committing swaps the whole tree, so stale pages cannot survive", {
  site <- withr::local_tempdir()
  live <- file.path(site, "src", "content", "docs")
  fs::dir_create(live)
  writeLines("old", file.path(live, "gone.md"))
  writeLines("old", file.path(live, "kept.md"))

  stage <- sd_new_stage(site)
  writeLines("new", file.path(stage$content, "kept.md"))
  writeLines("new", file.path(stage$content, "added.md"))

  sd_commit_dir(stage$content, live)

  expect_setequal(basename(fs::dir_ls(live)), c("kept.md", "added.md"))
  # The page whose source disappeared is gone, not stale.
  expect_false(file.exists(file.path(live, "gone.md")))
  expect_identical(readLines(file.path(live, "kept.md")), "new")
})

test_that("committing works when there is no live tree yet", {
  site <- withr::local_tempdir()
  live <- file.path(site, "src", "content", "docs")
  stage <- sd_new_stage(site)
  writeLines("new", file.path(stage$content, "a.md"))

  sd_commit_dir(stage$content, live)
  expect_true(file.exists(file.path(live, "a.md")))
})

test_that("public/ is merged, and only our own stale stubs are removed", {
  site <- withr::local_tempdir()
  live <- file.path(site, "public")
  fs::dir_create(file.path(live, "reference"))
  writeLines("user", file.path(live, "favicon.svg"))
  writeLines("stub", file.path(live, "reference", "old.html"))

  stage <- sd_new_stage(site)
  fs::dir_create(file.path(stage$public, "reference"))
  writeLines("stub", file.path(stage$public, "reference", "new.html"))

  written <- sd_commit_public(stage$public, live, previous = "reference/old.html")

  expect_identical(written, "reference/new.html")
  expect_true(file.exists(file.path(live, "reference", "new.html")))
  # A stub this build no longer wants goes.
  expect_false(file.exists(file.path(live, "reference", "old.html")))
  # Anything the user put there stays.
  expect_true(file.exists(file.path(live, "favicon.svg")))
})

test_that("a fresh stage never inherits the previous one", {
  site <- withr::local_tempdir()
  first <- sd_new_stage(site)
  writeLines("stale", file.path(first$content, "stale.md"))

  second <- sd_new_stage(site)
  expect_length(fs::dir_ls(second$content), 0L)
})
