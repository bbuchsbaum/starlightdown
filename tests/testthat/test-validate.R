stage_with <- function(pages, env = parent.frame()) {
  content <- withr::local_tempdir(.local_envir = env)
  for (name in names(pages)) {
    path <- file.path(content, name)
    fs::dir_create(dirname(path))
    writeLines(pages[[name]], path)
  }
  content
}

page <- function(title, body = "", sd = NULL) {
  front <- c("---", paste0("title: ", title))
  if (!is.null(sd)) {
    front <- c(front, sd)
  }
  c(front, "---", "", body)
}

test_that("a page without a title fails validation", {
  content <- stage_with(list("a.md" = c("---", "description: no title", "---", "", "Body.")))
  expect_match(sd_check_frontmatter(content), "no .*title", perl = TRUE)
})

test_that("unparseable frontmatter fails validation", {
  content <- stage_with(list("a.md" = c("---", "title: [unclosed", "---", "", "Body.")))
  expect_match(sd_check_frontmatter(content), "not valid YAML")
})

test_that("a lifecycle outside the schema's four fails validation", {
  # Astro's content collection would reject it and fail the whole site build.
  content <- stage_with(list(
    "a.md" = page("x", sd = c("sd:", "  kind: reference", "  lifecycle: maturing"))
  ))
  expect_match(sd_check_frontmatter(content), "lifecycle 'maturing'")

  ok <- stage_with(list(
    "a.md" = page("x", sd = c("sd:", "  kind: reference", "  lifecycle: stable"))
  ))
  expect_length(sd_check_frontmatter(ok), 0L)
})

test_that("an H1 in a body fails validation, but one in a code block does not", {
  bad <- stage_with(list("a.md" = page("x", "# A second H1")))
  expect_match(sd_check_no_reference_h1(bad), "contains an H1")

  good <- stage_with(list(
    "a.md" = page("x", c("```r", "# just a comment", "```", "", "## Fine"))
  ))
  expect_length(sd_check_no_reference_h1(good), 0L)
})

test_that("an untitled index group fails validation", {
  content <- stage_with(list(
    "reference/index.md" = page("Reference", sd = c(
      "sd:", "  kind: reference-index", "  groups:",
      "  - topics:", "    - name: a", "      slug: /reference/a/"
    ))
  ))
  expect_match(sd_check_index_groups(content), "group 1 has no title")
})

test_that("a bare-name index slug fails validation", {
  content <- stage_with(list(
    "reference/index.md" = page("Reference", sd = c(
      "sd:", "  kind: reference-index", "  groups:",
      "  - title: All", "    topics:", "    - name: a", "      slug: a"
    ))
  ))
  expect_match(sd_check_index_groups(content), "is not a route")
})

test_that("a missing image target fails validation", {
  content <- stage_with(list("a.md" = page("x", "![fig](figures/missing.png)")))
  expect_match(sd_check_relative_targets(content), "does not exist")

  fs::dir_create(file.path(content, "figures"))
  writeLines("x", file.path(content, "figures", "missing.png"))
  expect_length(sd_check_relative_targets(content), 0L)
})

test_that("a prose link matching no route fails validation", {
  content <- stage_with(list("a.md" = page("x", "[gone](/testpkg/reference/nope/)")))
  routes <- list(list(route = "/reference/real/", file = "a.md", kind = "reference"))
  manifest <- list(redirects = list())

  problems <- sd_check_prose_links(content, routes, manifest, fake_pkg())
  expect_match(problems, "matches no route")

  ok <- stage_with(list("a.md" = page("x", "[here](/testpkg/reference/real/)")))
  expect_length(sd_check_prose_links(ok, routes, manifest, fake_pkg()), 0L)
})

test_that("routes and files must be the same set", {
  content <- stage_with(list("a.md" = page("x"), "orphan.md" = page("y")))
  routes <- list(
    list(route = "/a/", file = "a.md", kind = "article"),
    list(route = "/ghost/", file = "ghost.md", kind = "article")
  )

  problems <- sd_check_route_bijection(content, routes)
  expect_match(problems[[1L]], "routes with no file: ghost.md")
  expect_match(problems[[2L]], "files with no route: orphan.md")
})

test_that("a stub written over a real page fails validation", {
  routes <- list(list(route = "/reference/", kind = "reference-index"))
  expect_match(
    sd_check_redirect_collisions(routes, "/reference/index.html"),
    "would overwrite"
  )
  expect_length(sd_check_redirect_collisions(routes, character()), 0L)
})

test_that("validation aborts listing every failure and commits nothing", {
  content <- stage_with(list(
    "a.md" = c("---", "description: no title", "---", "", "![x](nope.png)")
  ))
  stage <- list(content = content, public = withr::local_tempdir())
  routes <- list(list(route = "/a/", file = "a.md", kind = "article"))

  expect_error(
    sd_validate_stage(stage, routes, list(redirects = list()), fake_pkg()),
    "failed 2 validation checks"
  )
})
