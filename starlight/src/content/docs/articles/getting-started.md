---
title: 'Getting started with starlightdown'
---

`starlightdown` helps you turn an R package’s documentation into an
Astro Starlight site using `{altdoc}` for Markdown conversion and
`{pkgdown}` for navigation structure.

## Basic workflow

1.  Scaffold the Starlight site (once):

``` r
starlightdown::use_starlight_site()
```

1.  Render and sync docs whenever they change:

``` r
starlightdown::build_site(use_pkgdown_nav = TRUE)
```

1.  Preview the site:

``` r
system("cd starlight && npm run dev")
```

## What happens under the hood

-   `{altdoc}` renders README, man pages, and vignettes to `docs/`.
-   Files are mapped into `starlight/src/content/docs/` (README -\>
    `index.md`, vignettes -\> `articles/`, man pages -\> `reference/`).
-   Starlight frontmatter is injected and a sidebar can be generated
    from `{pkgdown}` metadata.

## Choosing a theme

`use_starlight_site()` and `build_site()` accept a `theme` argument:

``` r
starlightdown::use_starlight_site(theme = "ion")      # or "bauhaus" (default)
starlightdown::build_site(theme = "ion")
```

## Using Starlight UI features

Starlight supports several UI components. Since altdoc renders to
Markdown (which Quarto/Pandoc processes), starlightdown uses HTML
comment markers that survive rendering and get converted to proper
syntax during `build_site()`.

**Output formats:**

-   **`.md` (default)**: Supports Starlight callouts (`:::note`,
    `:::tip`, etc.). This is the default because most documentation only
    needs callouts.
-   **`.mdx` (opt-in)**: Enables JSX components like Tabs and Cards. Use
    `build_site(use_mdx = TRUE)` to enable.

### Callouts (Asides) — Works in `.md` (default)

Starlight provides callout boxes for notes, tips, cautions, and dangers:

:::note

This is a note callout rendered by Starlight.
:::
:::tip

Tips render with the accent color and icon.
:::
:::caution

Cautions get a warning treatment.
:::
:::danger

Danger callouts highlight critical warnings.
:::
**Syntax in vignettes:**

``` markdown

:::note

Your note text here.
:::
```

### Tabs — Requires `.mdx` (opt-in)

Use tabs to show alternative content (e.g., R vs Python examples).
**Note:** Requires `build_site(use_mdx = TRUE)`.

<!--mdx:Tabs-->
<!--mdx:TabItem label="R"-->

``` r
summary(lm(y ~ x, data = df))
```

<!--mdx:/TabItem-->
<!--mdx:TabItem label="Python"-->

``` python
import statsmodels.api as sm
model = sm.OLS(y, X).fit()
print(model.summary())
```

<!--mdx:/TabItem-->
<!--mdx:/Tabs-->

**Syntax in vignettes:**

``` markdown
<!--mdx:Tabs-->
<!--mdx:TabItem label="R"-->
Your R content here.
<!--mdx:/TabItem-->
<!--mdx:TabItem label="Python"-->
Your Python content here.
<!--mdx:/TabItem-->
<!--mdx:/Tabs-->
```

### Cards and LinkCards — Requires `.mdx` (opt-in)

Display content in card layouts. **Note:** Requires
`build_site(use_mdx = TRUE)`.

<!--mdx:CardGrid-->
<!--mdx:Card title="Getting Started"-->

Learn the basics of starlightdown. <!--mdx:/Card-->
<!--mdx:Card title="Themes"--> Customize your site’s appearance.
<!--mdx:/Card--> <!--mdx:/CardGrid-->

<!--mdx:LinkCard title="Starlight Docs" href="https://starlight.astro.build/"/-->

**Syntax:**

``` markdown
<!--mdx:CardGrid-->
<!--mdx:Card title="Title"-->
Card content here.
<!--mdx:/Card-->
<!--mdx:/CardGrid-->

<!--mdx:LinkCard title="Link Title" href="https://example.com"/-->
```

### Right sidebar (On this page)

Starlight auto-builds a Table of Contents from your headings. Keep a
clear heading hierarchy (`#`, `##`, `###`) and it will populate the
right sidebar.

### Pagination

Starlight provides “Previous / Next” links at the bottom automatically
based on your sidebar order. Use `_pkgdown.yml` to control
reference/article order and `use_pkgdown_nav = TRUE` to mirror that.
