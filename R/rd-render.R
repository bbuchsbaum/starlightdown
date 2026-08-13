# Rd -> Markdown ------------------------------------------------------------
#
# A recursive walker over parsed Rd fragments, dispatching on the `Rd_tag`
# attribute. Output is GitHub-flavoured Markdown: no HTML except where the Rd
# author asked for it via `\out{}`, and no MDX. Anything we don't recognise is
# reported once and rendered through, so an unknown tag degrades to its text
# instead of vanishing.

#' Render an Rd fragment to Markdown
#'
#' @param x A parsed Rd fragment (or whole file).
#' @param ctx A rendering context from `sd_rd_ctx()` / `sd_autolink_ctx()`.
#' @return A length-1 character vector.
#' @noRd
sd_rd_to_md <- function(x, ctx = sd_rd_ctx()) {
  if (is.null(x)) {
    return("")
  }

  tag <- attr(x, "Rd_tag")

  if (is.character(x)) {
    return(sd_rd_text(x, tag, ctx))
  }
  if (!is.list(x)) {
    return("")
  }
  if (is.null(tag) || !grepl("^\\\\", tag)) {
    return(sd_rd_children(x, ctx))
  }

  key <- sub("^\\\\", "", tag)
  handler <- sd_rd_handlers[[key]]
  if (is.null(handler)) {
    sd_warn_once(
      ctx,
      paste0("tag:", tag),
      "Unsupported Rd tag {.code {tag}}; rendering its contents as-is."
    )
    return(sd_rd_children(x, ctx))
  }
  handler(x, ctx)
}

#' Render and join the children of an Rd node
#'
#' Rd sources are indented for readability, which arrives as whitespace-only
#' TEXT nodes sitting between block constructs. Joining naively would push
#' prose in by two spaces (or into a code block at four), so in prose mode we
#' drop horizontal whitespace that lands at the start of a line. Verbatim mode
#' joins untouched: there, indentation is content.
#' @noRd
sd_rd_children <- function(x, ctx) {
  if (!length(x)) {
    return("")
  }
  parts <- vapply(x, sd_rd_to_md, character(1), ctx = ctx)
  if (isTRUE(ctx$verbatim)) {
    return(sd_cat0(parts))
  }

  out <- character()
  at_line_start <- FALSE
  for (part in parts) {
    if (!nzchar(part)) {
      next
    }
    if (at_line_start) {
      part <- sub("^[ \t]+", "", part)
      if (!nzchar(part)) {
        next
      }
    }
    out <- c(out, part)
    at_line_start <- grepl("\n[ \t]*$", part)
  }
  sd_cat0(out)
}

#' @noRd
sd_rd_arg <- function(x, i, ctx) {
  if (length(x) < i) {
    return("")
  }
  sd_rd_to_md(x[[i]], ctx)
}

#' @noRd
sd_rd_arg_text <- function(x, i) {
  if (length(x) < i) {
    return("")
  }
  trimws(sd_rd_flatten_text(x[[i]]))
}

# Leaves --------------------------------------------------------------------

#' @noRd
sd_rd_text <- function(x, tag, ctx) {
  tag <- tag %||% "TEXT"
  # USERMACRO leaves carry the *unexpanded* macro text; the expansion follows
  # them as ordinary siblings, so emitting both would duplicate the content.
  if (tag %in% c("COMMENT", "USERMACRO")) {
    return("")
  }
  txt <- sd_cat0(x)
  if (isTRUE(ctx$verbatim) || tag %in% c("RCODE", "VERB")) {
    return(txt)
  }
  sd_escape_md(sd_squash_ws(txt))
}

# Rd sources are indented for readability; that indentation is not content and
# four spaces at the start of a Markdown line would become a code block.
#' @noRd
sd_squash_ws <- function(x) {
  gsub("[ \t]*\n[ \t]*", "\n", x)
}

# Escape only what would otherwise change meaning. Underscores are escaped at
# word boundaries only, so `snake_case` survives intact; `<` and `&` only when
# they could open a tag or an entity.
#
# Line-start constructs matter more than they look: a description line
# beginning `# ` would become a second H1 on a reference page, which the
# frontend contract forbids outright. Escaping here is one-directional -- an
# unnecessary backslash renders as nothing, a missing one changes the document
# structure -- so the anchor is deliberately generous.
#' @noRd
sd_escape_md <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  x <- gsub("([`*\\[\\]])", "\\\\\\1", x, perl = TRUE)
  # One pass, so an underscore that is loose on both sides is escaped once.
  x <- gsub("(?<![A-Za-z0-9])_|_(?![A-Za-z0-9])", "\\\\_", x, perl = TRUE)
  x <- gsub("&(?=[A-Za-z#][A-Za-z0-9]{1,30};)", "&amp;", x, perl = TRUE)
  x <- gsub("<(?=[A-Za-z/!?])", "&lt;", x, perl = TRUE)
  sd_escape_line_starts(x)
}

#' @noRd
sd_escape_line_starts <- function(x) {
  x <- gsub("(^|\n)([ \t]*)#", "\\1\\2\\\\#", x, perl = TRUE)
  x <- gsub("(^|\n)([ \t]*)>", "\\1\\2\\\\>", x, perl = TRUE)
  x <- gsub("(^|\n)([ \t]*)([0-9]+)\\.(?=[ \t])", "\\1\\2\\3\\\\.", x, perl = TRUE)
  gsub("(^|\n)([ \t]*)([-+])(?=[ \t])", "\\1\\2\\\\\\3", x, perl = TRUE)
}

# Inline code, with a backtick fence long enough for the content.
#' @noRd
sd_code_span <- function(text) {
  if (!nzchar(text)) {
    return("")
  }
  runs <- regmatches(text, gregexpr("`+", text))[[1L]]
  n <- if (length(runs)) max(nchar(runs)) + 1L else 1L
  ticks <- strrep("`", n)
  pad <- if (grepl("^`|`$", text)) " " else ""
  paste0(ticks, pad, text, pad, ticks)
}

# Fenced block, with a fence long enough for the content.
#' @noRd
sd_code_fence <- function(body, info = "") {
  lines <- strsplit(body, "\n", fixed = TRUE)[[1L]]
  runs <- regmatches(lines, regexpr("^`{3,}", lines))
  n <- if (length(runs)) max(c(3L, nchar(runs) + 1L)) else 3L
  fence <- strrep("`", n)
  paste0(fence, info, "\n", body, "\n", fence)
}

#' @noRd
sd_block <- function(x) paste0("\n\n", x, "\n\n")

# Prefix the first line and indent the rest; used for list items.
#' @noRd
sd_indent_block <- function(text, marker) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  if (!length(lines)) {
    return("")
  }
  indent <- strrep(" ", nchar(marker))
  lines[[1L]] <- paste0(marker, lines[[1L]])
  if (length(lines) > 1L) {
    rest <- lines[-1L]
    lines[-1L] <- ifelse(nzchar(rest), paste0(indent, rest), "")
  }
  paste0(lines, collapse = "\n")
}

# Inline wrappers -----------------------------------------------------------

#' @noRd
sd_wrap_inline <- function(x, ctx, before, after = before) {
  body <- trimws(sd_rd_children(x, ctx))
  if (!nzchar(body)) {
    return("")
  }
  paste0(before, body, after)
}

#' @noRd
sd_verbatim_code <- function(x, ctx) {
  ctx$verbatim <- TRUE
  ctx$in_code <- TRUE
  sd_code_span(trimws(sd_rd_children(x, ctx)))
}

# `\code{}` may wrap a link (`\code{\link{foo}}`), in which case the link owns
# the code formatting. Text runs and links are rendered in sequence so mixed
# content survives.
#' @noRd
sd_render_code <- function(x, ctx) {
  ctx$verbatim <- TRUE
  ctx$in_code <- TRUE

  link_tags <- c("\\link", "\\linkS4class", "\\href", "\\url", "\\email")
  out <- character()
  buffer <- character()

  flush <- function() {
    text <- sd_cat0(buffer)
    buffer <<- character()
    if (nzchar(trimws(text))) {
      out <<- c(out, sd_code_span(text))
    }
  }

  for (el in x) {
    tag <- attr(el, "Rd_tag")
    if (!is.null(tag) && tag %in% link_tags) {
      flush()
      out <- c(out, sd_rd_to_md(el, ctx))
    } else {
      buffer <- c(buffer, sd_rd_to_md(el, ctx))
    }
  }
  flush()
  sd_cat0(out)
}

# Lists ---------------------------------------------------------------------

# In \itemize / \enumerate, `\item` is an empty marker and the item body is the
# sequence of siblings that follows it.
#' @noRd
sd_split_items <- function(x) {
  groups <- list()
  current <- NULL
  for (el in x) {
    if (identical(attr(el, "Rd_tag"), "\\item")) {
      if (!is.null(current)) {
        groups[[length(groups) + 1L]] <- current
      }
      current <- list()
    } else if (!is.null(current)) {
      current[[length(current) + 1L]] <- el
    }
  }
  if (!is.null(current)) {
    groups[[length(groups) + 1L]] <- current
  }
  groups
}

# In `inline` mode (inside a table cell) an item body is squashed onto one
# line, so the list survives as `<br>`-separated bullets instead of collapsing
# into an unreadable run-on.
#' @noRd
sd_flatten_lines <- function(x) trimws(gsub("[[:space:]]*\n[[:space:]]*", " ", x))

#' @noRd
sd_render_list <- function(x, ctx, ordered = FALSE) {
  items <- sd_split_items(x)
  inline <- isTRUE(ctx$inline)
  rendered <- character()
  for (i in seq_along(items)) {
    body <- sd_tidy_md(sd_rd_children(items[[i]], ctx))
    if (!nzchar(body)) {
      next
    }
    marker <- if (ordered) paste0(i, ". ") else "- "
    rendered <- c(rendered, if (inline) {
      paste0(marker, sd_flatten_lines(body))
    } else {
      sd_indent_block(body, marker)
    })
  }
  if (!length(rendered)) {
    return("")
  }
  sd_block(paste0(rendered, collapse = "\n"))
}

# \describe{} becomes a definition-style list: bold term, indented body.
#' @noRd
sd_render_describe <- function(x, ctx) {
  inline <- isTRUE(ctx$inline)
  rendered <- character()
  for (el in x) {
    if (!identical(attr(el, "Rd_tag"), "\\item")) {
      next
    }
    term <- sd_tidy_md(sd_rd_arg(el, 1L, ctx))
    body <- sd_tidy_md(sd_rd_arg(el, 2L, ctx))
    if (!nzchar(term) && !nzchar(body)) {
      next
    }
    if (inline) {
      line <- paste0("- **", sd_flatten_lines(term), "**")
      if (nzchar(body)) {
        line <- paste0(line, ": ", sd_flatten_lines(body))
      }
      rendered <- c(rendered, line)
      next
    }
    block <- paste0("**", term, "**")
    if (nzchar(body)) {
      block <- paste0(block, "\n\n", body)
    }
    rendered <- c(rendered, sd_indent_block(block, "- "))
  }
  if (!length(rendered)) {
    return("")
  }
  sd_block(paste0(rendered, collapse = "\n"))
}

# Tables --------------------------------------------------------------------

# GFM table cells are single-line, so structure that survived rendering (a
# nested list in an argument description, say) becomes explicit line breaks.
#' @noRd
sd_table_cell <- function(text) {
  text <- trimws(text)
  text <- gsub("\n[ \t]*\n", "\n", text)
  text <- gsub("\n[ \t]+", "\n", text)
  text <- gsub("[ \t]{2,}", " ", text)
  text <- gsub("|", "\\|", text, fixed = TRUE)
  gsub("\n", "<br>", text, fixed = TRUE)
}

#' @noRd
sd_render_tabular <- function(x, ctx) {
  spec <- gsub("[^lcr]", "", sd_rd_arg_text(x, 1L))
  align <- strsplit(spec, "")[[1L]]

  rows <- list()
  row <- character()
  cell <- character()

  end_cell <- function() {
    row <<- c(row, sd_table_cell(sd_cat0(cell)))
    cell <<- character()
  }
  end_row <- function() {
    end_cell()
    if (any(nzchar(row))) {
      rows[[length(rows) + 1L]] <<- row
    }
    row <<- character()
  }

  for (el in if (length(x) >= 2L) x[[2L]] else list()) {
    tag <- attr(el, "Rd_tag")
    if (identical(tag, "\\tab")) {
      end_cell()
    } else if (identical(tag, "\\cr")) {
      end_row()
    } else {
      cell <- c(cell, sd_rd_to_md(el, ctx))
    }
  }
  if (length(cell) || length(row)) {
    end_row()
  }

  if (!length(rows)) {
    return("")
  }

  ncol <- max(c(length(align), vapply(rows, length, integer(1))))
  align <- c(align, rep("l", ncol - length(align)))[seq_len(ncol)]
  rows <- lapply(rows, function(r) c(r, rep("", ncol - length(r)))[seq_len(ncol)])

  # A GFM table cannot nest inside a GFM table cell, and emitting one anyway
  # leaves the separator row visible as junk. Inside a cell, degrade to
  # readable rows instead.
  if (isTRUE(ctx$inline)) {
    separator <- " \u00b7 "
    lines <- vapply(
      rows,
      function(r) paste0(r[nzchar(r)], collapse = separator),
      character(1)
    )
    return(sd_block(paste0(lines[nzchar(lines)], collapse = "\n")))
  }

  rule <- vapply(align, function(a) {
    switch(a, c = ":---:", r = "---:", ":---")
  }, character(1))

  line <- function(cells) paste0("| ", paste0(cells, collapse = " | "), " |")
  body <- c(
    line(rows[[1L]]),
    line(rule),
    vapply(rows[-1L], line, character(1))
  )
  sd_block(paste0(body, collapse = "\n"))
}

# Conditional content -------------------------------------------------------

# We render for the web, so `html` and `text` branches are kept and everything
# else (latex, example-only) is dropped.
#' @noRd
sd_rd_condition_matches <- function(spec, ctx) {
  formats <- trimws(strsplit(spec, ",", fixed = TRUE)[[1L]])
  if (identical(formats, "TRUE")) {
    return(TRUE)
  }
  wanted <- if (isTRUE(ctx$html)) c("html", "text", "TRUE") else c("text", "TRUE")
  any(formats %in% wanted)
}

# \Sexpr --------------------------------------------------------------------

#' @noRd
sd_rd_sexpr_options <- function(x) {
  opt <- attr(x, "Rd_option")
  raw <- if (is.null(opt)) "" else sd_rd_flatten_text(opt)
  out <- list(results = "text", stage = "install")
  if (!nzchar(trimws(raw))) {
    return(out)
  }
  parts <- trimws(strsplit(raw, ",", fixed = TRUE)[[1L]])
  for (p in parts) {
    kv <- trimws(strsplit(p, "=", fixed = TRUE)[[1L]])
    if (length(kv) == 2L) {
      out[[kv[[1L]]]] <- kv[[2L]]
    }
  }
  out
}

# Every stage is evaluated at render time. R distinguishes build/install/render
# so that a value can be frozen into the installed help, but a documentation
# build has no such phases -- and dropping the other stages would silently
# delete Rdpack bibliographies, since `\insertRef{}` expands to
# `\Sexpr[results=rd,stage=build]{}`.
#' @noRd
sd_render_sexpr <- function(x, ctx) {
  opts <- sd_rd_sexpr_options(x)
  code <- sd_rd_flatten_text(x)

  if (identical(opts$results, "hide")) {
    return("")
  }

  env <- ctx$env
  if (!is.environment(env)) {
    env <- new.env(parent = globalenv())
  }
  value <- tryCatch(
    eval(parse(text = code), envir = env),
    error = function(e) {
      sd_warn_once(
        ctx,
        paste0("sexpr-error:", substr(code, 1L, 40L)),
        "Failed to evaluate a {.field Sexpr}: {conditionMessage(e)}"
      )
      NULL
    }
  )
  if (is.null(value)) {
    return("")
  }
  text <- sd_cat0(as.character(value))

  # `results=rd` means the value *is* Rd source and has to go back through the
  # parser; emitting it literally would print markup at the reader.
  if (identical(opts$results, "rd")) {
    return(sd_render_rd_fragment(text, ctx))
  }
  if (isTRUE(ctx$verbatim)) text else sd_escape_md(text)
}

#' @noRd
sd_render_rd_fragment <- function(text, ctx) {
  if (!nzchar(trimws(text))) {
    return("")
  }
  fragment <- tryCatch(
    {
      con <- textConnection(text)
      on.exit(close(con), add = TRUE)
      tools::parse_Rd(con, fragment = TRUE, encoding = "UTF-8")
    },
    error = function(e) NULL
  )
  if (is.null(fragment)) {
    sd_warn_once(
      ctx,
      "sexpr-rd-parse",
      "Could not parse the Rd returned by a {.field Sexpr}; using it as plain text."
    )
    return(if (isTRUE(ctx$verbatim)) text else sd_escape_md(text))
  }
  # parse_Rd() terminates a fragment with a newline; the value is inline.
  sub("\n+$", "", sd_rd_to_md(fragment, ctx))
}

# Handler table -------------------------------------------------------------

#' @noRd
sd_rd_handlers <- local({
  children <- function(x, ctx) sd_rd_children(x, ctx)
  drop <- function(x, ctx) ""
  code_like <- function(x, ctx) sd_verbatim_code(x, ctx)
  emphasise <- function(x, ctx) sd_wrap_inline(x, ctx, "*")
  strengthen <- function(x, ctx) sd_wrap_inline(x, ctx, "**")

  verbatim_children <- function(x, ctx) {
    ctx$verbatim <- TRUE
    sd_rd_children(x, ctx)
  }

  list(
    # Whole-file metadata: never part of a rendered body.
    name = drop,
    alias = drop,
    keyword = drop,
    concept = drop,
    docType = drop,
    encoding = drop,
    Rdversion = drop,
    newcommand = drop,
    renewcommand = drop,

    # Section containers: rendered when a section is handed to us directly.
    title = children,
    description = children,
    details = children,
    value = children,
    note = children,
    seealso = children,
    references = children,
    author = children,
    format = children,
    source = children,
    arguments = function(x, ctx) sd_render_describe(x, ctx),
    usage = verbatim_children,
    examples = verbatim_children,
    section = function(x, ctx) {
      paste0(
        sd_block(paste0("## ", sd_tidy_md(sd_rd_arg(x, 1L, ctx)))),
        sd_rd_arg(x, 2L, ctx)
      )
    },
    subsection = function(x, ctx) {
      paste0(
        sd_block(paste0("### ", sd_tidy_md(sd_rd_arg(x, 1L, ctx)))),
        sd_rd_arg(x, 2L, ctx)
      )
    },

    # Code.
    code = sd_render_code,
    verb = code_like,
    samp = code_like,
    file = code_like,
    env = code_like,
    option = code_like,
    command = code_like,
    kbd = code_like,
    pkg = code_like,
    preformatted = function(x, ctx) {
      ctx$verbatim <- TRUE
      body <- sd_rd_children(x, ctx)
      body <- sub("^\n+", "", sub("[ \t\n]+$", "", body))
      if (!nzchar(body)) {
        return("")
      }
      sd_block(sd_code_fence(body))
    },

    # Emphasis and quotation.
    emph = emphasise,
    italic = emphasise,
    var = emphasise,
    dfn = emphasise,
    cite = emphasise,
    strong = strengthen,
    bold = strengthen,
    acronym = children,
    abbr = children,
    sQuote = function(x, ctx) sd_wrap_inline(x, ctx, "\u2018", "\u2019"),
    dQuote = function(x, ctx) sd_wrap_inline(x, ctx, "\u201c", "\u201d"),

    # Links.
    link = function(x, ctx) {
      label_ctx <- ctx
      label_ctx$verbatim <- TRUE
      label <- sd_rd_children(x, label_ctx)
      sd_link_md(trimws(label), attr(x, "Rd_option"), trimws(label), ctx)
    },
    linkS4class = function(x, ctx) {
      label_ctx <- ctx
      label_ctx$verbatim <- TRUE
      label <- trimws(sd_rd_children(x, label_ctx))
      href <- sd_href_alias(paste0(label, "-class"), ctx)
      if (is.na(href)) {
        href <- sd_href_alias(label, ctx)
      }
      text <- if (isTRUE(ctx$in_code)) sd_code_span(label) else label
      if (is.na(href)) text else paste0("[", text, "](", href, ")")
    },
    href = function(x, ctx) {
      url <- sd_rd_arg_text(x, 1L)
      label <- trimws(sd_rd_arg(x, 2L, ctx))
      if (!nzchar(label)) {
        label <- url
      }
      paste0("[", label, "](", url, ")")
    },
    url = function(x, ctx) paste0("<", sd_rd_arg_text(x, 1L), ">"),
    email = function(x, ctx) {
      address <- sd_rd_arg_text(x, 1L)
      paste0("[", address, "](mailto:", address, ")")
    },
    figure = function(x, ctx) {
      file <- sd_rd_arg_text(x, 1L)
      alt <- sd_rd_arg_text(x, 2L)
      if (grepl("^options:", alt)) {
        m <- regmatches(alt, regexec("alt\\s*=\\s*['\"]([^'\"]*)['\"]", alt))[[1L]]
        alt <- if (length(m) >= 2L) m[[2L]] else ""
      }
      if (isTRUE(ctx$drop_lifecycle) && grepl("^lifecycle-", file)) {
        return("")
      }
      paste0("![", alt, "](figures/", file, ")")
    },

    # Lists and tables.
    itemize = function(x, ctx) sd_render_list(x, ctx, ordered = FALSE),
    enumerate = function(x, ctx) sd_render_list(x, ctx, ordered = TRUE),
    describe = sd_render_describe,
    item = function(x, ctx) {
      if (length(x) < 2L) {
        return(sd_rd_children(x, ctx))
      }
      sd_render_describe(list(x), ctx)
    },
    tabular = sd_render_tabular,
    tab = drop,
    cr = function(x, ctx) "\n",

    # Maths.
    eqn = function(x, ctx) {
      latex <- sd_rd_arg_text(x, 1L)
      if (!nzchar(latex)) "" else paste0("$", latex, "$")
    },
    deqn = function(x, ctx) {
      latex <- sd_rd_arg_text(x, 1L)
      if (!nzchar(latex)) "" else sd_block(paste0("$$\n", latex, "\n$$"))
    },

    # Methods, in usage sections.
    method = function(x, ctx) {
      paste0(sd_rd_arg_text(x, 1L), ".", sd_rd_arg_text(x, 2L))
    },
    S3method = function(x, ctx) {
      paste0(sd_rd_arg_text(x, 1L), ".", sd_rd_arg_text(x, 2L))
    },
    S4method = function(x, ctx) {
      paste0(
        "## S4 method for signature '", sd_rd_arg_text(x, 2L), "'\n",
        sd_rd_arg_text(x, 1L)
      )
    },

    # Example markers: the example runner re-walks these itself, so here we
    # only need their code to survive.
    dontrun = verbatim_children,
    donttest = verbatim_children,
    dontshow = verbatim_children,
    dontdiff = verbatim_children,
    testonly = verbatim_children,

    # Conditional and raw output.
    `if` = function(x, ctx) {
      if (sd_rd_condition_matches(sd_rd_arg_text(x, 1L), ctx)) {
        sd_rd_arg(x, 2L, ctx)
      } else {
        ""
      }
    },
    ifelse = function(x, ctx) {
      if (sd_rd_condition_matches(sd_rd_arg_text(x, 1L), ctx)) {
        sd_rd_arg(x, 2L, ctx)
      } else {
        sd_rd_arg(x, 3L, ctx)
      }
    },
    out = function(x, ctx) if (isTRUE(ctx$html)) sd_rd_arg_text(x, 1L) else "",
    special = function(x, ctx) sd_rd_arg_text(x, 1L),
    enc = function(x, ctx) sd_rd_arg(x, 1L, ctx),

    # Atoms.
    dots = function(x, ctx) "...",
    ldots = function(x, ctx) "...",
    R = function(x, ctx) "R",
    Sexpr = sd_render_sexpr
  )
})
