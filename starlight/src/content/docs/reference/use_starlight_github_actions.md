---
title: use_starlight_github_actions
description: Set up a GitHub Actions workflow for Starlight docs
sd:
  kind: reference
  name: use_starlight_github_actions
  aliases:
  - use_starlight_github_actions
  usage: |-
    use_starlight_github_actions(
      path = ".",
      branch = "main",
      site_dir = "starlight",
      overwrite = FALSE
    )
  source: man/use_starlight_github_actions.Rd
---

Writes a workflow that installs the package, builds the site with
[`build_site()`](/starlightdown/reference/build_site/), and deploys it to GitHub Pages. The workflow installs
Quarto (needed only if the package has vignettes) and uses `npm ci`, so
`<site_dir>/package-lock.json` must be committed — the scaffold ships one.

## Arguments

| Argument | Description |
| :--- | :--- |
| `path` | Package root directory. |
| `branch` | Git branch to publish from. |
| `site_dir` | Starlight project directory, relative to `path`. The built<br>output is taken from `<site_dir>/dist`. |
| `overwrite` | Whether to overwrite an existing workflow file. |

## Value

Invisibly, the path to the workflow file.

## Examples

```r
# Not run:
use_starlight_github_actions()
# End(Not run)
```
