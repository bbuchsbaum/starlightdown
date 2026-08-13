# Reference pages -----------------------------------------------------------
#
# One Markdown page per topic, plus an index. Everything the Starlight
# components need that isn't prose (name, aliases, usage, lifecycle,
# provenance, index grouping) travels as typed `sd:` frontmatter; everything
# that is prose stays in the body as plain GFM.
#
# Internal topics get pages but no index entry, matching pkgdown. Skipping them
# entirely would strand every `\link{}` that points at one, and cross-references
# from exported functions to internal helpers are common.

#' Render every reference topic into a staging directory
#'
#' @param pkg An `sd_pkg()` object.
#' @param stage_dir Content root; pages land in `<stage_dir>/reference/`.
#' @param examples Execute examples?
#' @param run_dont_run Execute `\dontrun{}` blocks too?
#' @return Invisibly, `list(topics = <route records>, index = <path>)`.
#' @noRd
sd_build_reference <- function(pkg,
                               stage_dir,
                               examples = TRUE,
                               run_dont_run = FALSE) {
  ctx <- sd_autolink_ctx(pkg)
  macros <- sd_rd_macros(pkg$src_path)

  ref_dir <- fs::path(stage_dir, "reference")
  fig_dir <- fs::path(ref_dir, "figures")
  fs::dir_create(ref_dir)

  sd_copy_man_figures(pkg, fig_dir)

  topics <- pkg$topics
  routes <- vector("list", nrow(topics))
  for (i in seq_len(nrow(topics))) {
    routes[[i]] <- sd_build_topic(
      topics[i, , drop = FALSE],
      pkg = pkg,
      ctx = ctx,
      macros = macros,
      ref_dir = ref_dir,
      fig_dir = fig_dir,
      examples = examples,
      run_dont_run = run_dont_run
    )
  }

  index <- sd_build_reference_index(pkg, routes, ref_dir)

  invisible(list(topics = routes, index = index))
}

# Rd may point at images in man/figures (lifecycle badges, diagrams); they live
# alongside the generated example figures so relative links resolve.
#' @noRd
sd_copy_man_figures <- function(pkg, fig_dir) {
  src <- fs::path(pkg$src_path, "man", "figures")
  if (!fs::dir_exists(src)) {
    return(invisible(character()))
  }
  files <- fs::dir_ls(src, type = "file")
  if (!length(files)) {
    return(invisible(character()))
  }
  fs::dir_create(fig_dir)
  fs::file_copy(files, fig_dir, overwrite = TRUE)
  invisible(as.character(files))
}

#' Render one topic
#' @noRd
sd_build_topic <- function(topic,
                           pkg,
                           ctx,
                           macros,
                           ref_dir,
                           fig_dir,
                           examples = TRUE,
                           run_dont_run = FALSE) {
  file_in <- topic$file_in[[1L]]
  slug <- sd_slug(topic$file_out[[1L]])
  name <- topic$name[[1L]]

  rd <- sd_rd_parse(
    fs::path(pkg$src_path, "man", file_in),
    pkg_path = pkg$src_path,
    macros = macros
  )
  sections <- sd_rd_sections(rd)

  lifecycle <- sd_topic_lifecycle(sections, topic)

  prose_ctx <- ctx
  prose_ctx$env <- sd_topic_env(ctx)
  prose_ctx$drop_lifecycle <- !is.null(lifecycle)

  title_text <- sd_plain_text(sections$title, prose_ctx)
  usage <- sd_render_usage(sections$usage, prose_ctx)
  source_path <- paste0("man/", file_in)

  ex <- sd_topic_examples(
    sections$examples,
    slug = slug,
    ctx = prose_ctx,
    fig_dir = fig_dir,
    examples = examples,
    run_dont_run = run_dont_run
  )

  # `\format` sits high because for a dataset topic it is the page. `\source`
  # and `\author` follow the sections they attribute.
  body <- sd_compact(list(
    sd_section_md(NULL, sections$description, prose_ctx),
    sd_section_md("Format", sections$format, prose_ctx),
    sd_arguments_md(sections$arguments, prose_ctx),
    sd_section_md("Details", sections$details, prose_ctx),
    sd_custom_sections_md(sections$sections, prose_ctx),
    sd_section_md("Value", sections$value, prose_ctx),
    sd_section_md("Source", sections$source, prose_ctx),
    sd_section_md("Note", sections$note, prose_ctx),
    sd_section_md("References", sections$references, prose_ctx),
    sd_section_md("Author", sections$author, prose_ctx),
    sd_section_md("See also", sections$seealso, prose_ctx),
    if (nzchar(ex$markdown)) paste0("## Examples\n\n", ex$markdown) else NULL
  ))

  frontmatter <- list(
    title = name,
    description = title_text,
    sd = sd_compact(list(
      kind = "reference",
      name = name,
      aliases = as.list(sections$aliases),
      usage = usage,
      # Package-root-relative, so the frontend can build a source URL from it.
      source = source_path,
      lifecycle = lifecycle,
      since = sd_topic_since(sections),
      family = sd_topic_family(topic),
      seealso = sd_topic_seealso(sections$seealso, ctx)
    ))
  )

  path <- fs::path(ref_dir, paste0(slug, ".md"))
  sd_write_file(
    paste0(sd_frontmatter(frontmatter), "\n", paste0(body, collapse = "\n\n"), "\n"),
    path
  )

  if (length(ex$errors)) {
    cli::cli_warn(
      "Examples for topic {.val {name}} raised an error: {.val {ex$errors}}"
    )
  }

  list(
    name = name,
    slug = slug,
    kind = "reference",
    title = title_text,
    # Base-less, as the contract requires for routes and index slugs.
    route = sd_reference_route(slug),
    file = paste0("reference/", slug, ".md"),
    source = source_path,
    aliases = sections$aliases,
    lifecycle = lifecycle,
    internal = isTRUE(as.logical(topic$internal[[1L]])),
    # Content-root-relative, so the manifest can compare routes to files.
    figures = paste0("reference/figures/", basename(ex$figures))
  )
}

#' @noRd
sd_reference_route <- function(slug) paste0("/reference/", slug, "/")

# The environment `\Sexpr{}` evaluates in: the package namespace when it is
# installed, so `\Sexpr[stage=render]{packageVersion(...)}` and friends work.
#' @noRd
sd_topic_env <- function(ctx) {
  if (!sd_is_string(ctx$package)) {
    return(NULL)
  }
  ns <- tryCatch(asNamespace(ctx$package), error = function(e) NULL)
  if (is.environment(ns)) new.env(parent = ns) else NULL
}

#' @noRd
sd_topic_examples <- function(examples_rd,
                              slug,
                              ctx,
                              fig_dir,
                              examples,
                              run_dont_run) {
  if (is.null(examples_rd)) {
    return(list(markdown = "", figures = character(), errors = character()))
  }
  sd_run_examples(
    examples_rd,
    topic_slug = slug,
    ctx = ctx,
    run_dont_run = run_dont_run,
    fig_dir = fig_dir,
    execute = isTRUE(examples)
  )
}

# Body helpers --------------------------------------------------------------

#' @noRd
sd_section_md <- function(heading, rd, ctx) {
  if (is.null(rd)) {
    return(NULL)
  }
  body <- sd_tidy_md(sd_rd_to_md(rd, ctx))
  if (!nzchar(body)) {
    return(NULL)
  }
  if (is.null(heading)) body else paste0("## ", heading, "\n\n", body)
}

#' @noRd
sd_custom_sections_md <- function(sections, ctx) {
  if (!length(sections)) {
    return(NULL)
  }
  parts <- vapply(
    sections,
    function(s) {
      title <- sd_tidy_md(sd_rd_to_md(s$title, ctx))
      body <- sd_tidy_md(sd_rd_to_md(s$content, ctx))
      if (!nzchar(title) && !nzchar(body)) {
        return("")
      }
      paste0("## ", title, "\n\n", body)
    },
    character(1)
  )
  parts <- parts[nzchar(parts)]
  if (!length(parts)) {
    return(NULL)
  }
  paste0(parts, collapse = "\n\n")
}

#' Arguments as a two-column GFM table
#'
#' Prose written directly inside `\arguments{}` (outside any `\item`) is kept
#' as a paragraph above the table rather than dropped -- packages use it for
#' notes that apply to every argument.
#' @noRd
sd_arguments_md <- function(arguments_rd, ctx) {
  if (is.null(arguments_rd)) {
    return(NULL)
  }
  name_ctx <- ctx
  name_ctx$verbatim <- TRUE
  name_ctx$in_code <- TRUE

  desc_ctx <- ctx
  desc_ctx$inline <- TRUE

  rows <- character()
  loose <- list()
  for (el in arguments_rd) {
    if (!identical(attr(el, "Rd_tag"), "\\item")) {
      loose[[length(loose) + 1L]] <- el
      next
    }
    names <- trimws(sd_rd_arg(el, 1L, name_ctx))
    desc <- sd_table_cell(sd_tidy_md(sd_rd_arg(el, 2L, desc_ctx)))
    if (!nzchar(names) && !nzchar(desc)) {
      next
    }
    labels <- trimws(strsplit(names, ",", fixed = TRUE)[[1L]])
    labels <- labels[nzchar(labels)]
    labels <- paste0(vapply(labels, sd_code_span, character(1)), collapse = ", ")
    rows <- c(rows, paste0("| ", sd_table_cell(labels), " | ", desc, " |"))
  }

  prose <- sd_tidy_md(sd_rd_children(loose, ctx))
  if (!length(rows)) {
    return(if (nzchar(prose)) paste0("## Arguments\n\n", prose) else NULL)
  }

  table <- paste0(
    c("| Argument | Description |", "| :--- | :--- |", rows),
    collapse = "\n"
  )
  paste0(
    "## Arguments\n\n",
    if (nzchar(prose)) paste0(prose, "\n\n") else "",
    table
  )
}

#' Usage as a plain string, for the `sd.usage` frontmatter field
#' @noRd
sd_render_usage <- function(usage_rd, ctx) {
  if (is.null(usage_rd)) {
    return(NULL)
  }
  usage_ctx <- ctx
  usage_ctx$verbatim <- TRUE
  usage_ctx$in_code <- TRUE
  text <- sd_rd_to_md(usage_rd, usage_ctx)
  text <- sd_trim_code(text)
  if (!nzchar(text)) NULL else text
}

#' Plain (markup-free) text of an Rd fragment, for YAML-carried metadata
#'
#' Rendered through the normal walker first -- flattening the raw fragment
#' would emit both halves of two-argument tags such as `\enc{Ω}{Omega}` -- then
#' stripped of inline Markdown decoration.
#' @noRd
sd_plain_text <- function(rd, ctx) {
  if (is.null(rd)) {
    return("")
  }
  text <- sd_rd_to_md(rd, ctx)
  text <- gsub("\\[([^]]*)\\]\\([^)]*\\)", "\\1", text)
  text <- gsub("`", "", text, fixed = TRUE)
  text <- gsub("\\*\\*([^*]+)\\*\\*", "\\1", text)
  text <- gsub("\\*([^*]+)\\*", "\\1", text)
  text <- gsub("\\\\([\\\\`*_#>.+-])", "\\1", text)
  text <- gsub("\\\\([\\[\\]])", "\\1", text)
  # The renderer's HTML entities are markup too: this string is plain text.
  text <- gsub("&lt;", "<", text, fixed = TRUE)
  text <- gsub("&gt;", ">", text, fixed = TRUE)
  text <- gsub("&amp;", "&", text, fixed = TRUE)
  trimws(gsub("[[:space:]]+", " ", text))
}

# See also, family, since ----------------------------------------------------

# Every `\link` in a `\seealso` section, as structured data. A topic in this
# package becomes a bare name the frontend resolves against `site.topics`; a
# topic elsewhere carries its own resolved href, because nothing on the
# frontend can look it up.
#' @noRd
sd_topic_seealso <- function(seealso_rd, ctx) {
  if (is.null(seealso_rd)) {
    return(NULL)
  }

  out <- list()
  seen <- character()
  for (node in sd_collect_link_nodes(seealso_rd)) {
    label <- trimws(sd_rd_flatten_text(node))
    opt <- attr(node, "Rd_option")
    opt <- if (is.null(opt)) "" else trimws(sd_rd_flatten_text(opt))

    if (identical(attr(node, "Rd_tag"), "\\linkS4class")) {
      label <- paste0(label, "-class")
      opt <- ""
    }

    entry <- sd_seealso_entry(label, opt, ctx)
    if (is.null(entry)) {
      next
    }
    key <- if (is.character(entry)) entry else paste0(entry$package, "::", entry$name)
    if (key %in% seen) {
      next
    }
    seen <- c(seen, key)
    out[[length(out) + 1L]] <- entry
  }

  if (!length(out)) NULL else out
}

#' @noRd
sd_seealso_entry <- function(label, opt, ctx) {
  if (!nzchar(label)) {
    return(NULL)
  }

  # `\link[=dest]{text}` names a topic in this package.
  if (grepl("^=", opt)) {
    return(sd_seealso_internal(sub("^=", "", opt), ctx))
  }

  if (nzchar(opt)) {
    parts <- strsplit(opt, ":", fixed = TRUE)[[1L]]
    package <- parts[[1L]]
    topic <- if (length(parts) > 1L) parts[[2L]] else label
    if (identical(package, ctx$package)) {
      return(sd_seealso_internal(topic, ctx))
    }
    href <- tryCatch(downlit::href_topic(topic, package), error = function(e) NA_character_)
    return(sd_compact(list(
      name = topic,
      package = package,
      href = if (length(href) == 1L && !is.na(href)) href else NULL
    )))
  }

  sd_seealso_internal(label, ctx)
}

# Bare strings are resolved by the frontend, so only a name it can actually
# find is worth emitting; anything else would render as plain text.
#' @noRd
sd_seealso_internal <- function(alias, ctx) {
  if (is.na(match(alias, names(ctx$aliases)))) {
    return(NULL)
  }
  alias
}

#' @noRd
sd_collect_link_nodes <- function(x) {
  if (is.null(x) || !is.list(x)) {
    return(list())
  }
  tag <- attr(x, "Rd_tag")
  if (!is.null(tag) && tag %in% c("\\link", "\\linkS4class")) {
    return(list(x))
  }
  out <- list()
  for (child in x) {
    out <- c(out, sd_collect_link_nodes(child))
  }
  out
}

# roxygen's `@family` becomes `\concept{}`, which is what pkgdown groups on.
#' @noRd
sd_topic_family <- function(topic) {
  concepts <- topic$concepts[[1L]]
  concepts <- as.character(concepts)
  concepts <- concepts[!is.na(concepts) & nzchar(concepts)]
  if (!length(concepts)) NULL else as.list(concepts)
}

# Rd has no `\since`, so this is best-effort: a custom `\section{Since}` or a
# user macro that produced a `\since` tag. Absent is the normal case.
#' @noRd
sd_topic_since <- function(sections) {
  for (section in sections$sections) {
    title <- tolower(trimws(sd_rd_flatten_text(section$title)))
    if (identical(title, "since")) {
      value <- trimws(sd_rd_flatten_text(section$content))
      version <- regmatches(value, regexpr("[0-9]+([.-][0-9]+)*", value))
      if (length(version) && nzchar(version)) {
        return(version[[1L]])
      }
    }
  }
  if (!is.null(sections$since)) {
    value <- trimws(sd_rd_flatten_text(sections$since))
    if (nzchar(value)) {
      return(value)
    }
  }
  NULL
}

# Lifecycle -----------------------------------------------------------------

# The {lifecycle} package has retired several stages over the years and old
# badges are still in the wild. The frontend schema knows four; anything else
# has to be folded onto one of them, because an unknown value fails Astro's
# content-collection validation and takes the whole site build down with it.
sd_lifecycle_map <- c(
  experimental = "experimental",
  maturing = "experimental",
  questioning = "experimental",
  stable = "stable",
  superseded = "superseded",
  retired = "superseded",
  deprecated = "deprecated",
  `soft-deprecated` = "deprecated",
  defunct = "deprecated",
  archived = "deprecated"
)

sd_lifecycle_stages <- names(sd_lifecycle_map)

#' @noRd
sd_normalise_lifecycle <- function(stage) {
  if (!sd_is_string(stage)) {
    return(NULL)
  }
  mapped <- sd_lifecycle_map[[tolower(stage)]]
  if (is.null(mapped)) NULL else unname(mapped)
}

#' @noRd
sd_topic_lifecycle <- function(sections, topic) {
  from_pkgdown <- topic$lifecycle[[1L]]
  if (length(from_pkgdown)) {
    mapped <- sd_normalise_lifecycle(as.character(from_pkgdown)[[1L]])
    if (!is.null(mapped)) {
      return(mapped)
    }
  }

  raw <- paste0(
    sd_rd_raw_text(sections$title),
    sd_rd_raw_text(sections$description)
  )

  badge <- regmatches(raw, regexec("lifecycle-([a-z-]+)\\.svg", raw))[[1L]]
  if (length(badge) >= 2L) {
    mapped <- sd_normalise_lifecycle(badge[[2L]])
    if (!is.null(mapped)) {
      return(mapped)
    }
  }

  pattern <- paste0("\\[(", paste0(sd_lifecycle_stages, collapse = "|"), ")\\]")
  label <- regmatches(tolower(raw), regexec(pattern, tolower(raw)))[[1L]]
  if (length(label) >= 2L) {
    return(sd_normalise_lifecycle(label[[2L]]))
  }

  NULL
}

# Index ---------------------------------------------------------------------

#' Write `reference/index.md`
#'
#' The body is intentionally empty: the grouped listing is data
#' (`sd.groups`), rendered by the Starlight `ReferenceIndex` component.
#' @noRd
sd_build_reference_index <- function(pkg, routes, ref_dir) {
  by_name <- routes
  names(by_name) <- vapply(routes, function(r) r$name, character(1))
  public <- names(by_name)[!vapply(by_name, function(r) isTRUE(r$internal), logical(1))]

  groups <- list()
  covered <- character()

  for (section in pkg$meta$reference) {
    names <- sd_select_topics(section$contents, pkg$topics, section = section$title)
    names <- intersect(names, names(by_name))
    covered <- union(covered, names)
    if (!length(names)) {
      next
    }
    groups[[length(groups) + 1L]] <- sd_compact(list(
      # The schema requires a title; untitled sections are legal pkgdown config.
      title = if (sd_is_string(section$title)) section$title else "Functions",
      desc = if (sd_is_string(section$desc)) section$desc else NULL,
      topics = sd_index_topics(by_name[names])
    ))
  }

  # A topic with a page but no section would be unreachable from the index, so
  # collect the leftovers rather than silently orphaning them. Internal topics
  # have pages so that links resolve, but are deliberately unlisted.
  leftover <- setdiff(public, covered)
  if (length(leftover)) {
    cli::cli_inform(c(
      "i" = "Topics not listed in any {.field reference} section: {.val {leftover}}.",
      " " = "Adding them to an {.val Other} group."
    ))
    groups[[length(groups) + 1L]] <- list(
      title = "Other",
      topics = sd_index_topics(by_name[leftover])
    )
  }

  title <- "Function reference"
  frontmatter <- list(
    title = title,
    sd = list(kind = "reference-index", groups = groups)
  )
  path <- fs::path(ref_dir, "index.md")
  sd_write_file(sd_frontmatter(frontmatter), path)

  list(
    name = "reference-index",
    slug = "index",
    kind = "reference-index",
    title = title,
    route = "/reference/",
    file = "reference/index.md",
    source = NULL
  )
}

#' @noRd
sd_index_topics <- function(routes) {
  unname(lapply(routes, function(r) {
    sd_compact(list(
      name = r$name,
      # A base-less route, not a bare name: the frontend prefixes the base and
      # links straight to this value.
      slug = r$route,
      summary = r$title,
      lifecycle = r$lifecycle
    ))
  }))
}
