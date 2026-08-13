# Link resolution -----------------------------------------------------------
#
# Internal `\link{}`s resolve against the package's own alias -> slug map, so
# they keep working no matter what the Rd file is called. Cross-package links
# go through downlit, which knows about pkgdown sites, CRAN and rdrr.io; when
# it can't resolve a target we degrade to plain code rather than emitting a
# dead link.

#' Build the rendering context for a package
#'
#' The context is threaded through every Rd renderer. Fields:
#' * `package`, `src_path`, `base` -- identity of the package being built.
#' * `aliases` -- named character, alias -> topic slug.
#' * `href_prefix` -- URL prefix (`"/"` or `"/pkg/"`) for internal links.
#' * `env` -- environment for `\Sexpr` evaluation and examples.
#' * `verbatim` / `in_code` -- renderer state, flipped while inside code.
#' * `html` -- whether `\if{html}` / `\out{}` content is kept.
#' * `drop_lifecycle` -- drop lifecycle badge figures (they go to frontmatter).
#' * `warned` -- environment backing warn-once diagnostics.
#'
#' @param pkg An `sd_pkg()` object.
#' @noRd
sd_autolink_ctx <- function(pkg) {
  aliases <- sd_alias_map(pkg$topics)
  sd_rd_ctx(
    package = pkg$package,
    aliases = aliases,
    base = pkg$base,
    src_path = pkg$src_path
  )
}

#' Bare rendering context, for tests and for Rd outside a package
#' @noRd
sd_rd_ctx <- function(package = NA_character_,
                      aliases = character(),
                      base = "/",
                      src_path = NA_character_,
                      env = NULL) {
  list(
    package = package,
    aliases = aliases,
    base = base,
    href_prefix = if (identical(base, "/") || !nzchar(base)) "/" else paste0(base, "/"),
    src_path = src_path,
    env = env,
    verbatim = FALSE,
    in_code = FALSE,
    inline = FALSE,
    html = TRUE,
    drop_lifecycle = FALSE,
    warned = new.env(parent = emptyenv())
  )
}

# alias -> slug, for every topic in the package.
#' @noRd
sd_alias_map <- function(topics) {
  if (!nrow(topics)) {
    return(character())
  }
  slugs <- sd_slug(topics$file_out)
  keys <- list()
  vals <- character()
  for (i in seq_len(nrow(topics))) {
    labels <- unique(c(topics$name[[i]], topics$alias[[i]]))
    keys <- c(keys, as.list(labels))
    vals <- c(vals, rep(slugs[[i]], length(labels)))
  }
  out <- vals
  names(out) <- unlist(keys, use.names = FALSE)
  out[!duplicated(names(out))]
}

#' URL for one of this package's reference topics
#' @noRd
sd_href_topic_internal <- function(slug, ctx) {
  paste0(ctx$href_prefix, "reference/", slug, "/")
}

#' Resolve a `\link` (or `\linkS4class`) to Markdown
#'
#' @param target Link destination as written in the Rd.
#' @param opt The `[...]` option, or `NULL`.
#' @param label Already-rendered link text.
#' @param ctx Rendering context.
#' @noRd
sd_link_md <- function(target, opt, label, ctx) {
  if (!nzchar(trimws(label))) {
    label <- target
  }
  # Inside `\code{}` the link owns the code formatting; in prose a `\link{}` is
  # ordinary link text.
  text <- if (isTRUE(ctx$in_code)) sd_code_span(label) else label

  href <- sd_link_href(target, opt, ctx)
  if (is.na(href)) {
    return(text)
  }
  paste0("[", text, "](", href, ")")
}

# Work out where a link points. NA means "no destination we trust".
#' @noRd
sd_link_href <- function(target, opt, ctx) {
  opt <- if (is.null(opt)) "" else trimws(sd_rd_flatten_text(opt))

  # \link[=dest]{text}: an alias in this package.
  if (grepl("^=", opt)) {
    return(sd_href_alias(sub("^=", "", opt), ctx))
  }

  # \link[pkg]{topic} and \link[pkg:topic]{text}.
  if (nzchar(opt)) {
    parts <- strsplit(opt, ":", fixed = TRUE)[[1L]]
    package <- parts[[1L]]
    topic <- if (length(parts) > 1L) parts[[2L]] else target
    if (identical(package, ctx$package)) {
      return(sd_href_alias(topic, ctx))
    }
    return(sd_href_external(topic, package, ctx))
  }

  sd_href_alias(target, ctx)
}

#' @noRd
sd_href_alias <- function(alias, ctx) {
  i <- match(alias, names(ctx$aliases))
  if (is.na(i)) {
    return(NA_character_)
  }
  sd_href_topic_internal(unname(ctx$aliases[[i]]), ctx)
}

#' @noRd
sd_href_external <- function(topic, package, ctx) {
  href <- tryCatch(
    downlit::href_topic(topic, package),
    error = function(e) NA_character_
  )
  if (length(href) != 1L || is.na(href)) {
    sd_warn_once(
      ctx,
      paste0("link:", package, "::", topic),
      "Can't resolve link to {.code {package}::{topic}}; rendering as plain code."
    )
    return(NA_character_)
  }
  href
}
