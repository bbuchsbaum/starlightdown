# Articles -------------------------------------------------------------------
#
# Vignettes are rendered by Quarto, in a copy of the package kept under the
# user cache. The copy exists so Quarto's freeze cache has somewhere stable to
# live: rendering in place would litter the package, and rendering in a fresh
# temp directory would re-execute every vignette on every build.
#
# What comes back from Quarto is GFM plus a `<name>_files/` directory. We strip
# the H1 it writes from the title (Starlight renders the frontmatter title as
# the page H1, and two would violate the contract), normalise its fence info
# strings, apply the site base to root-relative prose links, and write our own
# frontmatter.

#' Render every vignette into the staging directory
#'
#' @param pkg An `sd_pkg()` object.
#' @param stage_dir Content root; pages land in `<stage_dir>/articles/`.
#' @param lazy Reuse the freeze cache? `FALSE` clears it and re-executes.
#' @return Invisibly, a list of route records.
#' @noRd
sd_build_articles <- function(pkg, stage_dir, lazy = TRUE, quiet = FALSE) {
  vignettes <- pkg$vignettes
  if (!nrow(vignettes)) {
    return(invisible(list()))
  }

  bin <- sd_quarto_bin()
  sd_require_quarto(bin)

  build_dir <- sd_cache_build_dir(pkg)
  if (!isTRUE(lazy)) {
    unlink(build_dir, recursive = TRUE)
  }
  sd_sync_build_dir(pkg$src_path, build_dir)
  sd_write_quarto_config(build_dir, vignettes)

  if (!quiet) {
    cli::cli_inform("Rendering {nrow(vignettes)} article{?s} with Quarto.")
  }
  sd_quarto_render(
    wd = build_dir,
    targets = vignettes$file_in,
    to = "gfm",
    bin = bin,
    quiet = quiet
  )

  articles_dir <- fs::path(stage_dir, "articles")
  fs::dir_create(articles_dir)

  routes <- vector("list", nrow(vignettes))
  for (i in seq_len(nrow(vignettes))) {
    routes[[i]] <- sd_harvest_article(
      vignette = vignettes[i, , drop = FALSE],
      pkg = pkg,
      build_dir = build_dir,
      articles_dir = articles_dir
    )
  }

  invisible(routes)
}

# Build directory ------------------------------------------------------------

# Directories that must never travel into the build copy: the generated site,
# version control, node's world, and anything already derived.
sd_build_excludes <- c(
  "starlight", ".git", ".svn", "node_modules", ".Rproj.user",
  "revdep", "docs", ".github", ".quarto"
)

# Refresh the build copy in place, keeping `_freeze/` so unchanged vignettes
# are not re-executed.
#' @noRd
sd_sync_build_dir <- function(src, build_dir) {
  fs::dir_create(build_dir)

  keep <- c("_freeze")
  existing <- fs::dir_ls(build_dir, all = TRUE, type = "any")
  stale <- existing[!fs::path_file(existing) %in% keep]
  if (length(stale)) {
    unlink(stale, recursive = TRUE)
  }

  entries <- fs::dir_ls(src, all = TRUE, type = "any")
  entries <- entries[!fs::path_file(entries) %in% sd_build_excludes]
  entries <- entries[!grepl("\\.Rcheck$|\\.tar\\.gz$", fs::path_file(entries))]
  for (entry in entries) {
    target <- fs::path(build_dir, fs::path_file(entry))
    if (fs::is_dir(entry)) {
      fs::dir_copy(entry, target, overwrite = TRUE)
    } else {
      fs::file_copy(entry, target, overwrite = TRUE)
    }
  }
  invisible(build_dir)
}

# `_quarto.yml` is generated, never read from the package: the output format,
# the freeze policy and the knitr class options are ours to control. The class
# options are what turn knitr's output, messages, warnings and errors into the
# reserved fence info strings the Starlight side renders as output cells.
#' @noRd
sd_write_quarto_config <- function(build_dir, vignettes) {
  config <- list(
    project = list(
      type = "default",
      render = as.list(unname(vignettes$file_in))
    ),
    format = list(
      gfm = list(
        wrap = "preserve",
        `default-image-extension` = "png"
      )
    ),
    execute = list(
      freeze = "auto",
      echo = TRUE,
      warning = TRUE,
      error = FALSE,
      `fig-width` = 7,
      `fig-height` = 5,
      `fig-dpi` = 192
    ),
    knitr = list(
      opts_chunk = list(
        comment = "",
        collapse = FALSE,
        class.output = list("r-output"),
        class.message = list("r-message"),
        class.warning = list("r-warning"),
        class.error = list("r-error")
      )
    )
  )
  sd_write_file(sd_as_yaml(config), fs::path(build_dir, "_quarto.yml"))
}

# Harvest --------------------------------------------------------------------

#' @noRd
sd_harvest_article <- function(vignette, pkg, build_dir, articles_dir) {
  name <- vignette$name[[1L]]
  file_in <- vignette$file_in[[1L]]

  source_dir <- fs::path(build_dir, fs::path_dir(file_in))
  rendered <- fs::path(source_dir, paste0(fs::path_ext_remove(fs::path_file(file_in)), ".md"))
  if (!fs::file_exists(rendered)) {
    cli::cli_abort(c(
      "Quarto did not produce Markdown for {.path {file_in}}.",
      "i" = "Expected {.path {rendered}}."
    ))
  }

  body <- sd_read_utf8(rendered)
  body <- sd_strip_leading_h1(body)
  # A vignette with a YAML title routinely uses `#` for its own sections.
  # Starlight renders the frontmatter title as the page H1, so everything the
  # author wrote moves down one level rather than fighting for that slot.
  body <- paste0(sd_demote_headings(strsplit(body, "\n", fixed = TRUE)[[1L]]), collapse = "\n")
  body <- sd_normalise_quarto_fences(body)
  body <- sd_restore_root_links(body, depth = sd_path_depth(fs::path_dir(file_in)))
  body <- sd_apply_base_to_links(body, pkg$base)

  meta <- sd_article_metadata(fs::path(build_dir, file_in), vignette)
  frontmatter <- sd_compact(list(
    title = meta$title,
    description = meta$description,
    sd = list(kind = "article")
  ))

  page <- fs::path(articles_dir, paste0(name, ".md"))
  sd_write_file(paste0(sd_frontmatter(frontmatter), "\n", trimws(body), "\n"), page)

  assets <- sd_harvest_article_assets(body, source_dir, articles_dir)

  list(
    name = name,
    slug = name,
    kind = "article",
    title = meta$title,
    route = sd_article_route(name),
    file = paste0("articles/", name, ".md"),
    source = file_in,
    assets = assets
  )
}

# Starlight serves `articles/index.md` at `/articles/`, exactly as it serves
# `reference/index.md` at `/reference/`. Routing it to `/articles/index/`
# would name a page that is never generated.
#' @noRd
sd_article_route <- function(name) {
  if (identical(name, "index")) "/articles/" else paste0("/articles/", name, "/")
}

# Quarto writes figures into `<name>_files/`, and an article may also reference
# static images that live beside its source. Both have to travel next to the
# .md so Astro's asset pipeline can resolve them.
#' @noRd
sd_harvest_article_assets <- function(body, source_dir, articles_dir) {
  targets <- sd_relative_targets(body)
  copied <- character()

  for (target in targets) {
    from <- fs::path(source_dir, target)
    if (!fs::file_exists(from) && !fs::dir_exists(from)) {
      next
    }
    to <- fs::path(articles_dir, target)
    fs::dir_create(fs::path_dir(to))
    if (fs::is_dir(from)) {
      fs::dir_copy(from, to, overwrite = TRUE)
    } else {
      fs::file_copy(from, to, overwrite = TRUE)
    }
    copied <- c(copied, target)
  }

  unique(copied)
}

# Post-processing ------------------------------------------------------------

# Quarto writes the document title as an H1. Starlight renders the frontmatter
# title as the page H1, so keeping this one would put two on the page.
#' @noRd
sd_strip_leading_h1 <- function(body) {
  body <- sd_normalise_setext(body)
  lines <- strsplit(gsub("\r\n", "\n", body), "\n", fixed = TRUE)[[1L]]
  first <- which(nzchar(trimws(lines)))[1L]
  if (is.na(first) || !grepl("^#\\s+\\S", lines[[first]])) {
    return(body)
  }
  paste0(lines[-seq_len(first)], collapse = "\n")
}

# `Title` over `=====` is an H1 too, and READMEs still use it. Converting to
# ATX first means the strip and demote passes only have one form to handle.
#' @noRd
sd_normalise_setext <- function(body) {
  lines <- strsplit(gsub("\r\n", "\n", body), "\n", fixed = TRUE)[[1L]]
  if (length(lines) < 2L) {
    return(body)
  }

  keep <- rep(TRUE, length(lines))
  changed <- FALSE
  fence <- NA_character_
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (!is.na(fence)) {
      if (grepl(paste0("^[ \t]*", fence, "[ \t]*$"), line)) fence <- NA_character_
      next
    }
    opener <- regmatches(line, regexpr("^[ \t]*(`{3,}|~{3,})", line))
    if (length(opener) && nzchar(opener)) {
      fence <- sub("^[ \t]*", "", opener)
      next
    }
    if (i < 2L || !keep[[i - 1L]]) {
      next
    }
    previous <- lines[[i - 1L]]
    if (!nzchar(trimws(previous)) || grepl("^[ \t]*#", previous)) {
      next
    }
    if (grepl("^[ \t]{0,3}=+[ \t]*$", line)) {
      lines[[i - 1L]] <- paste0("# ", trimws(previous))
      keep[[i]] <- FALSE
      changed <- TRUE
    } else if (grepl("^[ \t]{0,3}-{2,}[ \t]*$", line)) {
      lines[[i - 1L]] <- paste0("## ", trimws(previous))
      keep[[i]] <- FALSE
      changed <- TRUE
    }
  }

  # Untouched documents come back byte-identical, trailing newline and all.
  if (!changed) {
    return(body)
  }
  paste0(lines[keep], collapse = "\n")
}

# Quarto emits "``` r"; the contract and the reference renderer both use
# "```r". Only the reserved R info strings are touched.
#' @noRd
sd_quarto_fence_infos <- c("r", "r-output", "r-message", "r-warning", "r-error")

#' @noRd
sd_normalise_quarto_fences <- function(body) {
  pattern <- paste0(
    "(?m)^(`{3,})[ \t]+(", paste0(sd_quarto_fence_infos, collapse = "|"), ")[ \t]*$"
  )
  gsub(pattern, "\\1\\2", body, perl = TRUE)
}

# Quarto resolves a root-relative link against the *project* root, so an author
# writing `/reference/add_one/` in `vignettes/intro.Rmd` gets
# `../reference/add_one/` back. From the article's own route that would resolve
# to `/articles/reference/add_one/`, which does not exist. Undo it: a target
# that climbs exactly out of the source directory was site-absolute to begin
# with. Images are left alone -- those really are relative assets.
#' @noRd
sd_restore_root_links <- function(body, depth) {
  if (!is.finite(depth) || depth < 1L) {
    return(body)
  }
  prefix <- strrep("\\.\\./", depth)
  gsub(
    paste0("(?<!!)\\]\\(", prefix, "(?!\\.\\./)([^)]*)\\)"),
    "](/\\1)",
    body,
    perl = TRUE
  )
}

#' @noRd
sd_path_depth <- function(path) {
  path <- as.character(path)
  if (!nzchar(path) || path %in% c(".", "/")) {
    return(0L)
  }
  length(strsplit(path, "/", fixed = TRUE)[[1L]])
}

# Prose links must carry the site base (CONTRACT.md §5): Starlight's markdown
# processor has no hook to rewrite them at build time, so R applies the base.
# Images stay relative -- Astro's asset pipeline handles those itself.
#' @noRd
sd_apply_base_to_links <- function(body, base) {
  if (!sd_is_string(base) || identical(base, "/")) {
    return(body)
  }
  prefix <- sub("/+$", "", base)
  already <- paste0(prefix, "/")

  sd_md_rewrite_targets(body, function(target) {
    # Root-relative only: external URLs, anchors and relative assets are the
    # author's business. Protocol-relative `//host` is a URL, not a route.
    if (!grepl("^/(?!/)", target, perl = TRUE)) {
      return(target)
    }
    if (identical(target, prefix) || startsWith(target, already)) {
      return(target)
    }
    paste0(prefix, target)
  })
}

# Metadata -------------------------------------------------------------------

# The source YAML is parsed here rather than taken from Quarto's output,
# because the GFM writer does not emit a frontmatter block at all.
#' @noRd
sd_article_metadata <- function(source_path, vignette) {
  yaml_block <- sd_read_yaml_header(source_path)

  title <- yaml_block$title %||% vignette$title[[1L]]
  description <- yaml_block$description %||% vignette$description[[1L]]

  list(
    title = if (sd_is_string(title)) title else vignette$name[[1L]],
    description = if (sd_is_string(description)) description else NULL
  )
}

#' Parse the YAML header of a source document
#' @noRd
sd_read_yaml_header <- function(path) {
  if (!fs::file_exists(path)) {
    return(list())
  }
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  marks <- which(trimws(lines) == "---")
  if (length(marks) < 2L || marks[[1L]] != 1L) {
    return(list())
  }
  block <- lines[seq(marks[[1L]] + 1L, marks[[2L]] - 1L)]
  parsed <- tryCatch(yaml::yaml.load(paste0(block, collapse = "\n")), error = function(e) NULL)
  if (is.list(parsed)) parsed else list()
}

#' @noRd
sd_read_utf8 <- function(path) {
  paste0(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}
