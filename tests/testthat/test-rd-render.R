test_that("inline markup renders", {
  expect_snapshot(cat(render_rd_section(c(
    "Plain prose with \\code{code}, \\verb{verbatim} and \\samp{a sample}.",
    "Files like \\file{DESCRIPTION}, variables like \\env{R_HOME}, options like",
    "\\option{--vanilla}, keys like \\kbd{Ctrl}, commands like \\command{make},",
    "packages like \\pkg{stats}.",
    "",
    "Emphasis: \\emph{emphasised}, \\strong{strong}, \\bold{bold},",
    "\\var{n}, \\dfn{a definition}, \\cite{a citation},",
    "\\acronym{CRAN}, \\abbr{Mr.}.",
    "",
    "Quotes: \\sQuote{single} and \\dQuote{double}. Ellipsis: \\dots and \\ldots.",
    "The \\R language."
  ))))
})

test_that("Markdown metacharacters in prose are escaped conservatively", {
  expect_snapshot(cat(render_rd_section(c(
    "A star * and an underscore _ and snake_case_name and [brackets] and",
    "a backtick ` and a backslash \\\\ and an angle x < 3 and a tag <b> and",
    "50\\% of a thing."
  ))))
})

test_that("code spans keep their content verbatim", {
  expect_snapshot(cat(render_rd_section(c(
    "Percent: \\code{100\\%}. Underscore: \\code{snake_case}. Star:",
    "\\code{a * b}. Backtick inside: \\verb{a ` b}."
  ))))
})

test_that("links resolve internally, by alias, and across packages", {
  expect_snapshot(cat(render_rd_section(c(
    "Internal \\link{other}, coded \\code{\\link{other}},",
    "aliased \\link[=other]{some text},",
    "cross-package \\link[stats]{lm} and \\link[stats:lm]{linear models},",
    "same-package-by-name \\link[testpkg]{other},",
    "S4 \\linkS4class{Foo},",
    "unresolvable \\link{no_such_topic}.",
    "",
    "External: \\href{https://example.com}{a link}, \\url{https://example.com},",
    "\\email{someone@example.com}."
  ))))
})

test_that("itemize, enumerate and describe become Markdown lists", {
  expect_snapshot(cat(render_rd_section(c(
    "\\itemize{",
    "  \\item first",
    "  \\item second, which continues",
    "        onto another line",
    "  \\item third, with a nested list:",
    "    \\enumerate{",
    "      \\item inner one",
    "      \\item inner two",
    "    }",
    "}",
    "",
    "\\describe{",
    "  \\item{alpha}{The first letter.}",
    "  \\item{beta}{The second letter, described",
    "              across two lines.}",
    "}"
  ))))
})

test_that("tabular becomes a GFM table with the declared alignment", {
  expect_snapshot(cat(render_rd_section(c(
    "\\tabular{lcr}{",
    "  Mode \\tab Result \\tab Note \\cr",
    "  integer \\tab exact \\tab none \\cr",
    "  double \\tab \\code{a|b} \\tab within \\code{eps} \\cr",
    "}"
  ))))
})

test_that("math renders as inline and display TeX", {
  expect_snapshot(cat(render_rd_section(c(
    "Inline \\eqn{a^2 + b^2}{a^2 + b^2} and display:",
    "\\deqn{\\sum_i x_i = 0}{sum(x) == 0}"
  ))))
})

test_that("preformatted blocks become fenced code", {
  expect_snapshot(cat(render_rd_section(c(
    "Before.",
    "\\preformatted{",
    "x <- 1",
    "  indented <- 2",
    "}",
    "After."
  ))))
})

test_that("conditional content keeps the html branch", {
  expect_snapshot(cat(render_rd_section(c(
    "\\if{html}{kept} \\if{latex}{dropped} \\if{text}{also kept}",
    "\\ifelse{html}{yes}{no} \\ifelse{latex}{no}{fallback}",
    "\\out{<span class=\"raw\">raw html</span>}"
  ))))
})

test_that("usage renders S3 and S4 method signatures", {
  expect_snapshot(cat(render_rd_section(
    c(
      "generic(x, ...)",
      "",
      "\\method{generic}{data.frame}(x, ...)",
      "",
      "\\S4method{generic}{Foo}(x, ...)"
    ),
    section = "usage"
  )))
})

test_that("figures render as images and honour the lifecycle drop flag", {
  ctx <- sd_rd_ctx(package = "testpkg", base = "/")
  expect_snapshot(cat(render_rd_section(
    c(
      "\\figure{diagram.png}{A diagram}",
      "\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}"
    ),
    ctx = ctx
  )))

  ctx$drop_lifecycle <- TRUE
  expect_snapshot(cat(render_rd_section(
    c(
      "\\figure{diagram.png}{A diagram}",
      "\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}"
    ),
    ctx = ctx
  )))
})

test_that("Sexpr is evaluated at every stage", {
  ctx <- sd_rd_ctx(package = "testpkg", base = "/")
  ctx$env <- new.env(parent = baseenv())

  expect_snapshot(
    cat(render_rd_section("Value: \\Sexpr[stage=render,results=text]{1 + 1}.", ctx = ctx))
  )
  # stage=install is the Rd default, and stage=build is what Rdpack's
  # \insertRef expands to; dropping either would delete real content.
  expect_identical(render_rd_section("Value: \\Sexpr{1 + 1}.", ctx = ctx), "Value: 2.")
  expect_identical(
    render_rd_section("Value: \\Sexpr[stage=build]{1 + 1}.", ctx = ctx),
    "Value: 2."
  )
  expect_identical(
    render_rd_section("Value: \\Sexpr[results=hide]{1 + 1}.", ctx = ctx),
    "Value: ."
  )
})

test_that("Rd returned by an Sexpr is parsed, not printed literally", {
  ctx <- sd_rd_ctx(package = "testpkg", aliases = c(other = "other"), base = "/base")

  expect_identical(sd_render_rd_fragment("\\emph{hello}", ctx), "*hello*")
  expect_identical(
    sd_render_rd_fragment("\\code{\\link{other}}", ctx),
    "[`other`](/base/reference/other/)"
  )
  expect_identical(sd_render_rd_fragment("   ", ctx), "")
})

test_that("Sexpr with results=rd is re-parsed as Rd", {
  ctx <- sd_rd_ctx(package = "testpkg", aliases = c(other = "other"), base = "/base")
  ctx$env <- new.env(parent = baseenv())

  # `intToUtf8(92)` is a backslash. Writing one literally here would have to
  # survive both R's string escaping and Rd's, which obscures the test.
  expect_identical(
    render_rd_section(
      "\\Sexpr[results=rd,stage=render]{paste0(intToUtf8(92), \"emph{hello}\")}",
      ctx = ctx
    ),
    "*hello*"
  )
  # stage=build is the stage Rdpack's \insertRef bibliography entries use.
  expect_identical(
    render_rd_section(
      "\\Sexpr[results=rd,stage=build]{paste0(intToUtf8(92), \"strong{cited}\")}",
      ctx = ctx
    ),
    "**cited**"
  )
})

test_that("line-start constructs in prose cannot become block markup", {
  # A reference body must contain no H1, and a stray "# " would be one.
  expect_snapshot(cat(render_rd_section(c(
    "# not a heading",
    "> not a quote",
    "1. not a list",
    "- not a bullet",
    "Ampersand entity: &copy; stays literal."
  ))))
})

test_that("unknown tags warn once and render their contents", {
  ctx <- sd_rd_ctx(package = "testpkg", base = "/")
  fragment <- structure(
    list(structure("content", Rd_tag = "TEXT")),
    Rd_tag = "\\madeUpTag"
  )

  expect_warning(out <- sd_rd_to_md(fragment, ctx), "Unsupported Rd tag")
  expect_identical(out, "content")

  # Warn-once: the same tag in the same context stays quiet from then on.
  expect_silent(sd_rd_to_md(fragment, ctx))
})

test_that("custom sections and subsections become headings", {
  path <- withr::local_tempfile(fileext = ".Rd")
  writeLines(c(
    "\\name{tmp}", "\\alias{tmp}", "\\title{Temp}",
    "\\details{",
    "Leading prose.",
    "\\subsection{A subsection}{",
    "Nested prose.",
    "}",
    "}",
    "\\section{A custom section}{",
    "Section prose.",
    "}"
  ), path)
  sections <- sd_rd_sections(sd_rd_parse(path))
  ctx <- sd_rd_ctx(package = "testpkg", base = "/")

  expect_snapshot(cat(sd_tidy_md(sd_rd_to_md(sections$details, ctx))))
  expect_length(sections$sections, 1L)
  expect_identical(sd_tidy_md(sd_rd_to_md(sections$sections[[1L]]$title, ctx)), "A custom section")
})
