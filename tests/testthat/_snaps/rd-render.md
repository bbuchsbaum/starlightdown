# inline markup renders

    Code
      cat(render_rd_section(c(
        "Plain prose with \\code{code}, \\verb{verbatim} and \\samp{a sample}.",
        "Files like \\file{DESCRIPTION}, variables like \\env{R_HOME}, options like",
        "\\option{--vanilla}, keys like \\kbd{Ctrl}, commands like \\command{make},",
        "packages like \\pkg{stats}.", "",
        "Emphasis: \\emph{emphasised}, \\strong{strong}, \\bold{bold},",
        "\\var{n}, \\dfn{a definition}, \\cite{a citation},",
        "\\acronym{CRAN}, \\abbr{Mr.}.", "",
        "Quotes: \\sQuote{single} and \\dQuote{double}. Ellipsis: \\dots and \\ldots.",
        "The \\R language.")))
    Output
      Plain prose with `code`, `verbatim` and `a sample`.
      Files like `DESCRIPTION`, variables like `R_HOME`, options like
      `--vanilla`, keys like `Ctrl`, commands like `make`,
      packages like `stats`.
      
      Emphasis: *emphasised*, **strong**, **bold**,
      *n*, *a definition*, *a citation*,
      CRAN, Mr..
      
      Quotes: ‘single’ and “double”. Ellipsis: ... and ....
      The R language.

# Markdown metacharacters in prose are escaped conservatively

    Code
      cat(render_rd_section(c(
        "A star * and an underscore _ and snake_case_name and [brackets] and",
        "a backtick ` and a backslash \\\\ and an angle x < 3 and a tag <b> and",
        "50\\% of a thing.")))
    Output
      A star \* and an underscore \_ and snake_case_name and \[brackets\] and
      a backtick \` and a backslash \\ and an angle x < 3 and a tag &lt;b> and
      50% of a thing.

# code spans keep their content verbatim

    Code
      cat(render_rd_section(c(
        "Percent: \\code{100\\%}. Underscore: \\code{snake_case}. Star:",
        "\\code{a * b}. Backtick inside: \\verb{a ` b}.")))
    Output
      Percent: `100%`. Underscore: `snake_case`. Star:
      `a * b`. Backtick inside: ``a ` b``.

# links resolve internally, by alias, and across packages

    Code
      cat(render_rd_section(c("Internal \\link{other}, coded \\code{\\link{other}},",
        "aliased \\link[=other]{some text},",
        "cross-package \\link[stats]{lm} and \\link[stats:lm]{linear models},",
        "same-package-by-name \\link[testpkg]{other},", "S4 \\linkS4class{Foo},",
        "unresolvable \\link{no_such_topic}.", "",
        "External: \\href{https://example.com}{a link}, \\url{https://example.com},",
        "\\email{someone@example.com}.")))
    Output
      Internal [other](/base/reference/other/), coded [`other`](/base/reference/other/),
      aliased [some text](/base/reference/other/),
      cross-package [lm](https://rdrr.io/r/stats/lm.html) and [linear models](https://rdrr.io/r/stats/lm.html),
      same-package-by-name [other](/base/reference/other/),
      S4 [Foo](/base/reference/Foo-class/),
      unresolvable no_such_topic.
      
      External: [a link](https://example.com), <https://example.com>,
      [someone@example.com](mailto:someone@example.com).

# itemize, enumerate and describe become Markdown lists

    Code
      cat(render_rd_section(c("\\itemize{", "  \\item first",
        "  \\item second, which continues", "        onto another line",
        "  \\item third, with a nested list:", "    \\enumerate{",
        "      \\item inner one", "      \\item inner two", "    }", "}", "",
        "\\describe{", "  \\item{alpha}{The first letter.}",
        "  \\item{beta}{The second letter, described",
        "              across two lines.}", "}")))
    Output
      - first
      - second, which continues
        onto another line
      - third, with a nested list:
      
        1. inner one
        2. inner two
      
      - **alpha**
      
        The first letter.
      - **beta**
      
        The second letter, described
        across two lines.

# tabular becomes a GFM table with the declared alignment

    Code
      cat(render_rd_section(c("\\tabular{lcr}{",
        "  Mode \\tab Result \\tab Note \\cr",
        "  integer \\tab exact \\tab none \\cr",
        "  double \\tab \\code{a|b} \\tab within \\code{eps} \\cr", "}")))
    Output
      | Mode | Result | Note |
      | :--- | :---: | ---: |
      | integer | exact | none |
      | double | `a\|b` | within `eps` |

# math renders as inline and display TeX

    Code
      cat(render_rd_section(c("Inline \\eqn{a^2 + b^2}{a^2 + b^2} and display:",
        "\\deqn{\\sum_i x_i = 0}{sum(x) == 0}")))
    Output
      Inline $a^2 + b^2$ and display:
      
      $$
      \sum_i x_i = 0
      $$

# preformatted blocks become fenced code

    Code
      cat(render_rd_section(c("Before.", "\\preformatted{", "x <- 1",
        "  indented <- 2", "}", "After.")))
    Output
      Before.
      
      ```
      x <- 1
        indented <- 2
      ```
      
      After.

# conditional content keeps the html branch

    Code
      cat(render_rd_section(c(
        "\\if{html}{kept} \\if{latex}{dropped} \\if{text}{also kept}",
        "\\ifelse{html}{yes}{no} \\ifelse{latex}{no}{fallback}",
        "\\out{<span class=\"raw\">raw html</span>}")))
    Output
      kept  also kept
      yes fallback
      <span class="raw">raw html</span>

# usage renders S3 and S4 method signatures

    Code
      cat(render_rd_section(c("generic(x, ...)", "",
        "\\method{generic}{data.frame}(x, ...)", "",
        "\\S4method{generic}{Foo}(x, ...)"), section = "usage"))
    Output
      generic(x, ...)
      
      generic.data.frame(x, ...)
      
      ## S4 method for signature 'Foo'
      generic(x, ...)

# figures render as images and honour the lifecycle drop flag

    Code
      cat(render_rd_section(c("\\figure{diagram.png}{A diagram}",
        "\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}"), ctx = ctx))
    Output
      ![A diagram](figures/diagram.png)
      ![[Experimental]](figures/lifecycle-experimental.svg)

---

    Code
      cat(render_rd_section(c("\\figure{diagram.png}{A diagram}",
        "\\figure{lifecycle-experimental.svg}{options: alt='[Experimental]'}"), ctx = ctx))
    Output
      ![A diagram](figures/diagram.png)

# Sexpr is evaluated at every stage

    Code
      cat(render_rd_section("Value: \\Sexpr[stage=render,results=text]{1 + 1}.", ctx = ctx))
    Output
      Value: 2.

# line-start constructs in prose cannot become block markup

    Code
      cat(render_rd_section(c("# not a heading", "> not a quote", "1. not a list",
        "- not a bullet", "Ampersand entity: &copy; stays literal.")))
    Output
      \# not a heading
      \> not a quote
      1\. not a list
      \- not a bullet
      Ampersand entity: &amp;copy; stays literal.

# custom sections and subsections become headings

    Code
      cat(sd_tidy_md(sd_rd_to_md(sections$details, ctx)))
    Output
      Leading prose.
      
      ### A subsection
      
      Nested prose.

