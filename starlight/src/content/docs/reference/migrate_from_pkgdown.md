---
title: migrate_from_pkgdown
description: Migrate a pkgdown site to starlightdown
sd:
  kind: reference
  name: migrate_from_pkgdown
  aliases:
  - migrate_from_pkgdown
  usage: |-
    migrate_from_pkgdown(
      path = ".",
      site_dir = "starlight",
      scaffold = TRUE,
      quiet = FALSE
    )
  source: man/migrate_from_pkgdown.Rd
  seealso:
  - build_site
---

Scaffolds the Starlight project if it is not there yet and reports what
your `_pkgdown.yml` means for the new site. **Nothing is rewritten**: your
`_pkgdown.yml` stays exactly as it is and remains the source of truth for
navigation, so you can run both site generators side by side.

## Arguments

| Argument | Description |
| :--- | :--- |
| `path` | Package root directory. |
| `site_dir` | Starlight project directory, relative to `path`. |
| `scaffold` | Create the Starlight project if it is missing? |
| `quiet` | Suppress the printed report? |

## Value

Invisibly, a list with `carried` (settings that apply as-is),
`manual` (settings needing attention) and `site_dir`.

## See also

[`build_site()`](/starlightdown/reference/build_site/), which does the actual work afterwards.

## Examples

```r
# Not run:
migrate_from_pkgdown()
build_site()
# End(Not run)
```
