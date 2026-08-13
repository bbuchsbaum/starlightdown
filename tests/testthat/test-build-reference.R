# The default build is deterministic and read-only here, so run it once.
built_reference <- local({
  cache <- NULL

  function() {
    if (!is.null(cache)) {
      return(cache)
    }
    fixture <- full_fixture()
    pkg <- sd_pkg(fixture$path)
    stage <- withr::local_tempdir("sd-ref", .local_envir = teardown_env())
    routes <- sd_build_reference(pkg, stage)
    cache <<- list(pkg = pkg, stage = stage, routes = routes)
    cache
  }
})

test_that("every topic gets a page, internal ones included", {
  built <- built_reference()

  expect_true(all(file.exists(file.path(
    built$stage, "reference",
    c(
      "index.md", "full_add.md", "full_config.md", "full_describe.md",
      "full_experimental.md", "full_plot.md", "full_quotes.md"
    )
  ))))
  expect_length(built$routes$topics, 8L)

  # Internal topics are documented but unlisted: pkgdown does the same, and
  # skipping them would strand every \link{} that points at one.
  internal <- Filter(function(r) isTRUE(r$internal), built$routes$topics)
  expect_length(internal, 1L)
  expect_identical(internal[[1L]]$name, "full_internal")
  expect_true(file.exists(file.path(built$stage, internal[[1L]]$file)))

  index <- read_frontmatter(file.path(built$stage, "reference", "index.md"))
  listed <- unlist(lapply(index$sd$groups, function(g) {
    vapply(g$topics, function(t) t$name, character(1))
  }))
  expect_false("full_internal" %in% listed)
})

test_that("a link to an internal topic resolves to a page that exists", {
  built <- built_reference()
  body <- read_body(file.path(built$stage, "reference", "full_add.md"))

  expect_match(body, "(/testpkg.full/reference/full_internal/)", fixed = TRUE)
  expect_true(file.exists(file.path(built$stage, "reference", "full_internal.md")))
})

test_that("frontmatter is valid YAML and round-trips apostrophes and unicode", {
  built <- built_reference()

  quotes <- read_frontmatter(file.path(built$stage, "reference", "full_quotes.md"))
  expect_identical(quotes$title, "full_quotes")
  expect_identical(quotes$description, "Find one's bearings with Ω and friends")
  expect_identical(quotes$sd$kind, "reference")
  expect_identical(quotes$sd$usage, "full_quotes()")
  # Package-root-relative, so the frontend can build a working source URL.
  expect_identical(quotes$sd$source, "man/full_quotes.Rd")

  add <- read_frontmatter(file.path(built$stage, "reference", "full_add.md"))
  expect_identical(add$sd$aliases, c("full_add", "full_plus"))
  expect_identical(add$sd$usage, "full_add(x, y = 1)")

  describe <- read_frontmatter(file.path(built$stage, "reference", "full_describe.md"))
  expect_identical(
    describe$sd$usage,
    "full_describe(x, ...)\n\nfull_describe.default(x, ...)"
  )
})

test_that("lifecycle badges move from the body into frontmatter", {
  built <- built_reference()
  path <- file.path(built$stage, "reference", "full_experimental.md")

  expect_identical(read_frontmatter(path)$sd$lifecycle, "experimental")
  expect_false(grepl("lifecycle-experimental.svg", read_body(path), fixed = TRUE))

  # Topics without a badge carry no lifecycle key at all.
  expect_null(read_frontmatter(file.path(built$stage, "reference", "full_add.md"))$sd$lifecycle)
})

test_that("usage lives in frontmatter, never in the body", {
  built <- built_reference()
  body <- read_body(file.path(built$stage, "reference", "full_add.md"))

  expect_false(grepl("## Usage", body, fixed = TRUE))
  expect_match(body, "## Arguments", fixed = TRUE)
  expect_match(body, "## Examples", fixed = TRUE)
})

test_that("arguments render as a well-formed two-column table", {
  built <- built_reference()
  body <- read_body(file.path(built$stage, "reference", "full_add.md"))

  lines <- strsplit(body, "\n", fixed = TRUE)[[1L]]
  start <- which(lines == "## Arguments")
  table <- lines[seq(start + 2L, start + 5L)]

  expect_identical(table[[1L]], "| Argument | Description |")
  expect_identical(table[[2L]], "| :--- | :--- |")
  expect_true(all(grepl("^\\| .* \\| .* \\|$", table[3:4])))
  expect_match(table[[3L]], "`x`", fixed = TRUE)
})

test_that("argument descriptions survive block content in a table cell", {
  path <- withr::local_tempfile(fileext = ".Rd")
  writeLines(c(
    "\\name{tmp}", "\\alias{tmp}", "\\title{Temp}",
    "\\arguments{",
    "Applies to every argument below.",
    "\\item{x}{One of:",
    "  \\itemize{",
    "    \\item first",
    "    \\item second",
    "  }}",
    "\\item{y}{A lookup:",
    "  \\tabular{ll}{",
    "    key \\tab value \\cr",
    "    a \\tab 1 \\cr",
    "  }}",
    "\\item{}{An argument with no name.}",
    "}"
  ), path)
  sections <- sd_rd_sections(sd_rd_parse(path))
  out <- sd_arguments_md(sections$arguments, sd_rd_ctx(base = "/"))

  lines <- strsplit(out, "\n", fixed = TRUE)[[1L]]
  rows <- grep("^\\|", lines, value = TRUE)

  # Prose written outside any \item is kept, not dropped.
  expect_match(out, "Applies to every argument below.", fixed = TRUE)
  # Header, separator and one row per item, including the unnamed one.
  expect_length(rows, 5L)
  expect_true(all(vapply(
    rows,
    function(r) lengths(regmatches(r, gregexpr("(?<!\\\\)\\|", r, perl = TRUE))) == 3L,
    logical(1)
  )))
  # A nested table degrades to legible text rather than table syntax.
  expect_false(grepl(":---:", rows[[4L]], fixed = TRUE))
  expect_match(rows[[4L]], "key", fixed = TRUE)
  expect_match(rows[[5L]], "An argument with no name.", fixed = TRUE)
})

test_that("links resolve internally with the site base and externally via downlit", {
  built <- built_reference()
  body <- read_body(file.path(built$stage, "reference", "full_add.md"))

  expect_match(body, "(/testpkg.full/reference/full_config/)", fixed = TRUE)
  expect_match(body, "https://rdrr.io/r/stats/lm.html", fixed = TRUE)
})

test_that("examples run, and their figures exist where the page points", {
  built <- built_reference()
  body <- read_body(file.path(built$stage, "reference", "full_plot.md"))

  expect_match(body, "![](figures/full_plot-1.png)", fixed = TRUE)
  expect_match(body, "![](figures/full_plot-2.png)", fixed = TRUE)
  expect_true(all(file.exists(file.path(
    built$stage, "reference", "figures",
    c("full_plot-1.png", "full_plot-2.png")
  ))))

  # man/figures assets travel alongside the generated ones.
  expect_true(file.exists(file.path(
    built$stage, "reference", "figures", "lifecycle-experimental.svg"
  )))

  quotes <- read_body(file.path(built$stage, "reference", "full_quotes.md"))
  # Output is unprefixed: CONTRACT.md §7 fuses the output block onto the source
  # block visually, so a `#> ` comment marker would be redundant noise, and
  # article cells from Quarto are unprefixed too.
  expect_match(quotes, "```r-output\n[1] \"one's bearings\"", fixed = TRUE)
  expect_match(quotes, "# Not run:", fixed = TRUE)
  expect_match(quotes, "```r-message\nthis block does run", fixed = TRUE)
})

test_that("the reference index mirrors the _pkgdown.yml sections", {
  built <- built_reference()
  index <- read_frontmatter(file.path(built$stage, "reference", "index.md"))

  expect_identical(index$sd$kind, "reference-index")
  expect_length(index$sd$groups, 2L)
  expect_identical(index$sd$groups[[1L]]$title, "Core, one's favourites")
  expect_identical(
    vapply(index$sd$groups[[1L]]$topics, function(x) x$name, character(1)),
    c("full_add", "full_config")
  )
  # Slugs are base-less routes, not bare names: the frontend links to them.
  expect_identical(
    vapply(index$sd$groups[[2L]]$topics, function(x) x$slug, character(1)),
    c(
      "/reference/full_describe/", "/reference/full_experimental/",
      "/reference/full_plot/", "/reference/full_quotes/",
      "/reference/full_ops/"
    )
  )
  expect_identical(index$sd$groups[[1L]]$topics[[1L]]$slug, "/reference/full_add/")
  expect_identical(index$sd$groups[[2L]]$topics[[2L]]$lifecycle, "experimental")
  expect_identical(index$sd$groups[[1L]]$topics[[1L]]$summary, "Add two numbers")

  # Every slug must point at a page that was actually written.
  slugs <- unlist(lapply(index$sd$groups, function(g) {
    vapply(g$topics, function(t) t$slug, character(1))
  }))
  files <- file.path(
    built$stage, sub("^/", "", sub("/$", ".md", slugs))
  )
  expect_true(all(file.exists(files)))

  # The body is deliberately empty: the grouping is data for the frontend.
  expect_identical(trimws(read_body(file.path(built$stage, "reference", "index.md"))), "")
})

test_that("topics missing from every section still reach the index", {
  fixture <- full_fixture()
  pkg <- sd_pkg(fixture$path)
  pkg$meta$reference <- list(list(title = "Just one", contents = list("full_add")))
  stage <- withr::local_tempdir()

  expect_message(
    sd_build_reference(pkg, stage, examples = FALSE),
    "not listed in any"
  )

  index <- read_frontmatter(file.path(stage, "reference", "index.md"))
  expect_length(index$sd$groups, 2L)
  expect_identical(index$sd$groups[[2L]]$title, "Other")
  # Everything public except full_add; the internal topic stays unlisted.
  expect_length(index$sd$groups[[2L]]$topics, 6L)
})

test_that("an untitled reference section still gets a title", {
  fixture <- full_fixture()
  pkg <- sd_pkg(fixture$path)
  pkg$meta$reference <- list(list(contents = list('starts_with("full_")')))
  stage <- withr::local_tempdir()

  suppressMessages(sd_build_reference(pkg, stage, examples = FALSE))

  index <- read_frontmatter(file.path(stage, "reference", "index.md"))
  # The frontend schema requires a title on every group.
  expect_true(all(vapply(
    index$sd$groups,
    function(g) sd_is_string(g$title),
    logical(1)
  )))
  expect_identical(index$sd$groups[[1L]]$title, "Functions")
})

test_that("a whole reference page is stable", {
  built <- built_reference()
  expect_snapshot(cat(readLines(
    file.path(built$stage, "reference", "full_add.md"),
    warn = FALSE, encoding = "UTF-8"
  ), sep = "\n"))
})

test_that("the reference index page is stable", {
  built <- built_reference()
  expect_snapshot(cat(readLines(
    file.path(built$stage, "reference", "index.md"),
    warn = FALSE, encoding = "UTF-8"
  ), sep = "\n"))
})

test_that("route records describe what was written", {
  built <- built_reference()
  route <- Filter(function(r) r$name == "full_plot", built$routes$topics)[[1L]]

  expect_identical(route$slug, "full_plot")
  expect_identical(route$kind, "reference")
  expect_identical(route$file, "reference/full_plot.md")
  expect_identical(route$source, "man/full_plot.Rd")
  expect_identical(
    route$figures,
    c("reference/figures/full_plot-1.png", "reference/figures/full_plot-2.png")
  )
  expect_true(all(file.exists(file.path(built$stage, route$figures))))
})

test_that("a package with no _pkgdown.yml builds against the default model", {
  pkg <- sd_pkg(local_fixture_pkg("testpkg.minimal"))
  stage <- withr::local_tempdir()

  routes <- sd_build_reference(pkg, stage, examples = FALSE)

  expect_length(routes$topics, 2L)
  index <- read_frontmatter(file.path(stage, "reference", "index.md"))
  expect_length(index$sd$groups, 1L)
  expect_identical(index$sd$groups[[1L]]$title, "All functions")
  expect_identical(
    vapply(index$sd$groups[[1L]]$topics, function(x) x$name, character(1)),
    c("add_one", "times_two")
  )

  # No site URL in DESCRIPTION, so internal links start at the site root.
  body <- read_body(file.path(stage, "reference", "add_one.md"))
  expect_match(body, "## Examples", fixed = TRUE)
  expect_match(body, "```r\nadd_one(41)\n```", fixed = TRUE)
})

test_that("see-also, family and since reach the frontmatter", {
  built <- built_reference()
  front <- read_frontmatter(file.path(built$stage, "reference", "full_add.md"))

  # A topic in this package is a bare name the frontend resolves; one
  # elsewhere carries its own href, because nothing on the frontend can look
  # it up.
  expect_identical(front$sd$seealso[[1L]], "full_describe")
  expect_identical(front$sd$seealso[[2L]], "full_internal")
  expect_identical(front$sd$seealso[[3L]]$name, "lm")
  expect_identical(front$sd$seealso[[3L]]$package, "stats")
  expect_match(front$sd$seealso[[3L]]$href, "^https://")

  # roxygen's @family becomes \concept{}.
  expect_identical(unlist(front$sd$family), "arithmetic")

  # A topic with no \seealso carries no key at all.
  plain <- read_frontmatter(file.path(built$stage, "reference", "full_plot.md"))
  expect_null(plain$sd$seealso)
  expect_null(plain$sd$since)
})

test_that("an unresolvable see-also target is dropped rather than linked", {
  ctx <- sd_rd_ctx(package = "testpkg", aliases = c(known = "known"), base = "/")
  expect_identical(sd_seealso_internal("known", ctx), "known")
  expect_null(sd_seealso_internal("no_such_topic", ctx))
})
