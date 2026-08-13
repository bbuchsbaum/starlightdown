# Plan

## Goals
- Ship an R package (`starlightdown`) that turns package docs into an Astro Starlight site.
- Leverage `{altdoc}` for Markdown rendering and `{pkgdown}` for navigation structure.
- Provide a minimal Starlight template and R helpers for build/preview.

## Milestones
- M1: Scaffold docs workflow (Vision/Plan/Architecture/Progress docs created). **Status:** in progress.
- M2: Add R package skeleton (DESCRIPTION, R/ functions, inst/ template).
- M3: Implement doc sync + frontmatter helpers and basic sidebar.
- M4: Optional pkgdown-driven sidebar generator and homepage polish.

## Immediate actions
- Keep reference clones `altdoc/` and `pkgdown/` ignored in Git.
- Draft architecture and progress logs to guide the implementation phase.
- Use confirmed package name `starlightdown` in metadata and templates.

## Risks / considerations
- Starlight frontmatter requirements on all pages; need reliable injection.
- Dependency versions for Astro/Starlight/sharp; pin in template.
- Handling pkgdown navigation mapping across packages with custom `_pkgdown.yml`.
