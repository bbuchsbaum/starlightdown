---
title: use_starlight_site
description: Scaffold an Astro Starlight project for this package
sd:
  kind: reference
  name: use_starlight_site
  aliases:
  - use_starlight_site
  usage: |-
    use_starlight_site(
      path = ".",
      site_dir = "starlight",
      overwrite = FALSE,
      npm_install = TRUE
    )
  source: man/use_starlight_site.Rd
---

Creates `site_dir/` from the bundled template, vendors the Starlight plugin
into `site_dir/.starlightdown/`, and installs the Node dependencies if npm
is available. Everything outside `.starlightdown/` is yours to edit; that
directory is regenerated on every [`build_site()`](/starlightdown/reference/build_site/).

## Arguments

| Argument | Description |
| :--- | :--- |
| `path` | Package root directory. |
| `site_dir` | Subdirectory where the Starlight project will live. |
| `overwrite` | Whether to overwrite an existing directory at `site_dir`. |
| `npm_install` | Run `npm install` to create the lockfile? |

## Value

Invisibly, the path to `site_dir`.
