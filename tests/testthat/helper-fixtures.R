# Copy a fixture package into a fresh temp dir and return its path.
local_fixture_pkg <- function(name = "testpkg.minimal", env = parent.frame()) {
  src <- test_path("fixtures", name)
  dest <- file.path(withr::local_tempdir(.local_envir = env), name)
  fs::dir_copy(src, dest)
  materialise_fixture(dest)
  dest
}

# The fixture's `inst/CITATION` is kept outside the fixture package: R CMD
# check reports any CITATION file below the package root as ours and
# misplaced. It is installed into the copy instead.
materialise_fixture <- function(dest) {
  # Only the full fixture has one; testpkg.minimal deliberately does not, so
  # the DESCRIPTION-derived fallback stays covered.
  template <- test_path("fixtures", "citation-template.R")
  if (identical(basename(dest), "testpkg.full") && file.exists(template)) {
    fs::dir_create(file.path(dest, "inst"))
    fs::file_copy(template, file.path(dest, "inst", "CITATION"), overwrite = TRUE)
  }
  invisible(dest)
}

# `testpkg.full` is installed once per test run into a temporary library:
# examples are evaluated in a child of the package namespace, exactly as
# `example()` does, which needs the package on the library path. Subsequent
# calls reuse the installation.
full_fixture <- local({
  cache <- NULL

  function() {
    if (!is.null(cache)) {
      if (!isTRUE(cache$ok)) {
        skip(cache$reason)
      }
      return(cache)
    }

    teardown <- teardown_env()
    root <- withr::local_tempdir("sd-full", .local_envir = teardown)
    src <- file.path(root, "testpkg.full")
    fs::dir_copy(test_path("fixtures", "testpkg.full"), src)
    materialise_fixture(src)

    lib <- file.path(root, "lib")
    dir.create(lib, showWarnings = FALSE)

    result <- processx::run(
      file.path(R.home("bin"), "R"),
      c(
        "CMD", "INSTALL", "--no-multiarch", "--no-byte-compile", "--no-help",
        "-l", lib, src
      ),
      error_on_status = FALSE
    )

    if (result$status != 0L) {
      cache <<- list(
        ok = FALSE,
        reason = paste0("R CMD INSTALL of testpkg.full failed:\n", result$stderr)
      )
      skip(cache$reason)
    }

    withr::local_libpaths(lib, action = "prefix", .local_envir = teardown)
    withr::defer(try(unloadNamespace("testpkg.full"), silent = TRUE), envir = teardown)
    loadNamespace("testpkg.full")

    cache <<- list(ok = TRUE, path = src, lib = lib)
    cache
  }
})

# A minimal stand-in for an sd_pkg, for the helpers that only need base/url.
fake_pkg <- function(base = "/testpkg", url = "https://example.github.io") {
  list(base = base, site_url = url)
}

# A representative set of route records, for the manifest/sidebar helpers.
fake_routes <- function() {
  list(
    list(name = "index", slug = "index", kind = "home", title = "A Package",
         route = "/", file = "index.md"),
    list(name = "intro", slug = "intro", kind = "article", title = "Intro",
         route = "/articles/intro/", file = "articles/intro.md"),
    list(name = "reference-index", slug = "index", kind = "reference-index",
         title = "Function reference", route = "/reference/",
         file = "reference/index.md"),
    list(name = "add_one", slug = "add_one", kind = "reference", title = "Add one",
         route = "/reference/add_one/", file = "reference/add_one.md",
         aliases = c("add_one", "add1"), lifecycle = "stable", internal = FALSE),
    list(name = "secret", slug = "secret", kind = "reference", title = "Internal",
         route = "/reference/secret/", file = "reference/secret.md",
         aliases = "secret", internal = TRUE)
  )
}

skip_if_no_quarto <- function() {
  skip_if(!sd_is_string(sd_quarto_bin()), "Quarto is not installed")
}

# A scaffolded site with a full build in it, produced once per test run.
# Article rendering costs a Quarto session, so this is worth caching.
built_site <- local({
  cache <- NULL

  function(...) {
    if (!is.null(cache)) {
      return(cache)
    }
    skip_if_no_quarto()
    fixture <- full_fixture()

    root <- withr::local_tempdir("sd-site", .local_envir = teardown_env())
    src <- file.path(root, "testpkg.full")
    fs::dir_copy(fixture$path, src)
    withr::local_envvar(
      c(STARLIGHTDOWN_CACHE_DIR = file.path(root, "cache")),
      .local_envir = teardown_env()
    )

    use_starlight_site(path = src, npm_install = FALSE)
    build_site(path = src, quiet = TRUE, ...)

    cache <<- list(pkg_path = src, site = file.path(src, "starlight"))
    cache
  }
})

# The generated manifest, as a list.
read_manifest <- function(site) {
  jsonlite::read_json(file.path(site, ".starlightdown", "site.json"))
}

# Frontmatter of a generated page, as a list.
read_frontmatter <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  marks <- which(lines == "---")
  if (length(marks) < 2L) {
    stop("No frontmatter block in ", path)
  }
  yaml::yaml.load(paste(lines[seq(marks[[1L]] + 1L, marks[[2L]] - 1L)], collapse = "\n"))
}

# Body of a generated page (everything after the frontmatter), as one string.
read_body <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  marks <- which(lines == "---")
  if (marks[[2L]] >= length(lines)) {
    return("")
  }
  paste(lines[seq(marks[[2L]] + 1L, length(lines))], collapse = "\n")
}

# Render an Rd section written inline, for tag-level snapshot tests.
render_rd_section <- function(lines, section = "description", ctx = NULL, env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".Rd", .local_envir = env)
  writeLines(
    c(
      "\\name{tmp}", "\\alias{tmp}", "\\title{Temp}",
      paste0("\\", section, "{"), lines, "}"
    ),
    path
  )
  rd <- sd_rd_parse(path)
  if (is.null(ctx)) {
    ctx <- sd_rd_ctx(
      package = "testpkg",
      aliases = c(tmp = "tmp", other = "other", `Foo-class` = "Foo-class"),
      base = "/base"
    )
  }
  sd_tidy_md(sd_rd_to_md(sd_rd_sections(rd)[[section]], ctx))
}
