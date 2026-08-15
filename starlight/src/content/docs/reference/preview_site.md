---
title: preview_site
description: Preview the Starlight site with a development server
sd:
  kind: reference
  name: preview_site
  aliases:
  - preview_site
  usage: preview_site(path = ".", site_dir = "starlight", npm_args = c("run", "dev"))
  source: man/preview_site.Rd
---

Runs `npm run dev` in the Starlight project directory. The server runs in
the foreground until interrupted. You must have run `npm install` in
`site_dir` first (or `use_starlight_site()` followed by `npm install`).

## Arguments

| Argument | Description |
| :--- | :--- |
| `path` | Package root directory. |
| `site_dir` | Starlight project directory, relative to `path`. |
| `npm_args` | Character vector of arguments passed to `npm`.<br>Defaults to `c("run", "dev")`. |

## Value

Invisibly, the exit status of the npm command.
