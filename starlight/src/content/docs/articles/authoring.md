---
title: Theming and authoring
sd:
  kind: article
---

Two things this vignette covers: how to change how the site looks, and which
Starlight features you can reach from a vignette.

The second question has a non-obvious answer, because your vignette is not
handed to Starlight directly. Quarto executes it and writes Markdown, and only
then does Starlight render it. Quarto rewrites some of what you write on the
way through. Everything below was verified by building it, not inferred.

## Theming

### Pick a theme

```r
starlightdown::build_site(theme = "nova")
```

Or set it once, in `_pkgdown.yml`:

``` yaml
starlightdown:
  theme: default
```

`"default"` is the bundled editorial theme. `"nova"` is
[starlight-theme-nova](https://github.com/ocavue/starlight-theme-nova),
installed for you when selected. Choosing a preset swaps the visual design but
keeps the R-specific pieces — reference page headers, argument tables, and the
code/output cells — because those are styled against their own classes rather
than the theme’s.

### Change colors and type

The default theme is built from a small set of custom properties. Override any
of them in `starlight/src/styles/custom.css`, which loads last:

``` css
/* Starlight's convention, which the theme follows: :root is dark, and
   [data-theme='light'] overrides it. Set both, or a theme switch will
   half-apply your change. */
:root {
  --sd-accent: #7fd1bb;
}

:root[data-theme='light'] {
  --sd-accent: #1f6f5c;
  --sd-paper: #fffdf8;
}
```

The tokens are:

| Group | Tokens |
|----|----|
| Surfaces | `--sd-paper`, `--sd-surface`, `--sd-hairline`, `--sd-hairline-strong` |
| Text | `--sd-ink`, `--sd-ink-strong`, `--sd-ink-muted` |
| Accent | `--sd-accent`, `--sd-accent-muted`, `--sd-accent-wash` |
| Code | `--sd-code-bg`, `--sd-code-border`, `--sd-code-chrome` |
| Output cells | `--sd-output-bg`, `--sd-output-ink`, `--sd-rule-message`, `--sd-rule-warning`, `--sd-rule-error` |
| Figures | `--sd-figure-plate` |

`--sd-figure-plate` is the pale panel drawn behind
raster plots in dark mode, so a white-background R plot does not glare; set it
to `transparent`, or add `class="sd-dark-ok"` to an image that already handles
dark backgrounds.

Fonts are set with `--sd-font-serif`, `--sd-font-sans` and `--sd-font-mono`.

### Change code block appearance

Code blocks are rendered by
[Expressive Code](https://expressive-code.com/). Override its options in
`starlight/ec.config.mjs`:

``` js
import { defineEcConfig } from '@astrojs/starlight/expressive-code';
import ecConfig from 'starlightdown-starlight/ec-config';

export default defineEcConfig({
  ...ecConfig,
  themes: ['catppuccin-latte', 'catppuccin-mocha'],
  styleOverrides: { ...ecConfig.styleOverrides, codeFontSize: '1rem' },
});
```

### What is yours and what is not

Everything under `starlight/.starlightdown/` is regenerated on every build:
the manifest, the generated config, and the vendored frontend plugin. Do not
edit it.

Everything else is yours and is never rewritten — `astro.config.mjs`,
`src/styles/custom.css`, `ec.config.mjs`, and `package.json`, whose
dependencies starlightdown edits structurally rather than by rewriting text.

## Authoring vignettes

### Callouts

Use Quarto’s callout syntax. It becomes a Starlight aside:

``` markdown
::: {.callout-note}
Neutral guidance.
:::

::: {.callout-warning title="Mind this"}
A titled callout.
:::
```

Quarto’s five types map onto Starlight’s four asides: `note` and `important`
become **note**, `tip` becomes **tip**, `warning` becomes **caution**, and
`caution` becomes **danger**.

Do **not** write Starlight’s `:::note` directly in a vignette. Quarto reads it
as a plain fenced div and emits `<div class="note">`, which is unstyled. This
is the one place where the obvious syntax is the wrong one.

Quarto also claims the `callout-` prefix on raw HTML. A `<div class="callout callout-mine">` is captured by Quarto, and any variant it does not recognise
loses its identity before starlightdown sees the document. If you style your
own callouts, use a class name that does not begin with `callout-`.

### Code block features

Expressive Code supports titles, line highlighting, diff markers and word
wrapping — but the attributes have to reach the Markdown intact, and Quarto
strips them from ordinary fences. Wrap the block in a raw Markdown block,
using four backticks outside so the inner fence survives:

````` markdown
````{=markdown}
```r title="analysis.R" {2}
fit <- lm(mpg ~ wt, mtcars)
summary(fit)
```
````
`````

The same trick reaches any Markdown that Quarto would otherwise rewrite,
including an aside with a custom title:

```` markdown
```{=markdown}
:::tip[Worth knowing]
Body of the aside.
:::
```
````

Attributes written directly on a fence — \`\`\`\` \`\`\`\`\` — are worse
than ignored: Pandoc does not recognise them, and the block stops being a code
block at all.

### Figures

Chunks that produce plots work normally, and the figures are optimised by
Astro’s asset pipeline:

```` markdown

::: {.cell}

```{.r .cell-code}
plot(mpg ~ wt, mtcars)
```
:::
````

Setting `fig-align` or `out.width` makes Quarto emit raw HTML instead of a
Markdown image; starlightdown converts those back so the figure still reaches
the built site. Prefer sizing figures with `fig.width` and `fig.height`, which
control the device rather than the markup.

### Output cells

R source and its output are rendered as one fused cell. Output, messages,
warnings and errors are each styled distinctly, and are excluded from the
search index so a page is found by its prose rather than its console noise.

This needs nothing from you — it is how executed chunks are emitted.

### Linking

Link to another page with a site-absolute path; the base is applied for you:

``` markdown
See [the reference index](/reference/) and [add_one()](/reference/add_one/).
```

Every link is checked at build time against the pages actually generated, so a
typo fails the build instead of shipping.

In a README, link to repository files as you normally would. A link to
`NEWS.md` or a vignette source becomes a link to its page on the site; a link
to anything else in the repository becomes a link into the repository.

### What works, and what does not

Verified by building each case:

| Feature | Status |
|----|----|
| Quarto callouts, titled or not | Works |
| Math, inline and display | Works |
| Footnotes | Works |
| Tables and task lists | Works |
| Executed chunks, output, warnings, messages, plots | Works |
| Raw HTML, if the class does not start with `callout-` | Works |
| Code titles, line highlighting, diffs | Needs a `{=markdown}` raw block |
| Asides with custom titles | Needs a `{=markdown}` raw block |
| Bare `:::note` | Becomes an unstyled div |
| Starlight components (`<Tabs>`, `<Card>`, `<Steps>`) | Not available |

The last row is a deliberate limitation. Those are MDX components, and pages
are generated as Markdown. Generating MDX from R would mean escaping every
`{`, `}` and `<` that appears in R code and console output — the failure mode
that broke this package’s previous implementation. Tabs and cards are
available to hand-written pages you add to `src/content/docs/` yourself as
`.mdx`; they are not available to generated ones.
