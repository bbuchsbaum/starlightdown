---
title: build_site
description: Build the Starlight documentation site for a package
sd:
  kind: reference
  name: build_site
  aliases:
  - build_site
  usage: |-
    build_site(
      path = ".",
      site_dir = "starlight",
      articles = TRUE,
      examples = TRUE,
      run_dont_run = FALSE,
      lazy = TRUE,
      theme = NULL,
      npm_build = FALSE,
      quiet = FALSE
    )
  source: man/build_site.Rd
---

Compiles package documentation (reference topics, articles, README, NEWS,
citation) into the Starlight content collection at
`<site_dir>/src/content/docs/`, along with a typed `site.json` manifest
consumed by the bundled Starlight plugin. Output is staged, validated, and
committed atomically: a failed build never touches the live site, and
removed source pages cannot survive as stale output.

## Arguments

| Argument | Description |
| :--- | :--- |
| `path` | Package root directory. |
| `site_dir` | Starlight project directory, relative to `path`. |
| `articles` | Build vignettes/articles (requires Quarto)? |
| `examples` | Run examples in reference topics? |
| `run_dont_run` | Run `\dontrun{}` example blocks? |
| `lazy` | Reuse cached article renders when sources are unchanged? |
| `theme` | Site theme: `"default"` for the bundled Editorial Scientific<br>theme, or `"nova"` for that preset. `NULL` reads<br>`starlightdown: theme:` from `_pkgdown.yml`. |
| `npm_build` | If `TRUE`, run `npm run build` after generating content. |
| `quiet` | Suppress progress messages? |

## Value

Invisibly, the path to `site_dir`.

## Examples

```r
# Not run:
build_site()
# End(Not run)
```
