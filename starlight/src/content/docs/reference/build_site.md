---
title: 'Build an Astro Starlight docs site for this package'
---

## Description

This:

<ol>
<li>

Uses <code>altdoc::render_docs()</code> to render your package docs into
<code style="white-space: pre;">docs/</code>

</li>
<li>

Copies/renames those Markdown files into
<code style="white-space: pre;">src/content/docs/</code> in a Starlight
project.

</li>
<li>

Ensures minimal Starlight frontmatter
(<code style="white-space: pre;">title:</code>) for each page.

</li>
<li>

Optionally runs <code style="white-space: pre;">npm run build</code>.

</li>
</ol>

## Usage

<pre><code class='language-R'>build_site(
  path = ".",
  site_dir = "starlight",
  generator = c("altdoc"),
  npm_build = FALSE,
  use_pkgdown_nav = FALSE,
  verbose = FALSE,
  theme = NULL
)
</code></pre>

## Arguments

<table role="presentation">
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="path">path</code>
</td>
<td>
Package root directory.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="site_dir">site_dir</code>
</td>
<td>
Starlight project directory, relative to <code>path</code>.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="generator">generator</code>
</td>
<td>
Currently only <code>“altdoc”</code> is supported.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="npm_build">npm_build</code>
</td>
<td>
If <code>TRUE</code>, run <code style="white-space: pre;">npm run
build</code> after syncing docs.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="use_pkgdown_nav">use_pkgdown_nav</code>
</td>
<td>
(Reserved for future use.) If <code>TRUE</code> and
<code>{pkgdown}</code> is installed, sidebar navigation can be refined
later based on <code style="white-space: pre;">\_pkgdown.yml</code>.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="verbose">verbose</code>
</td>
<td>
Passed to <code>altdoc::render_docs()</code>.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="theme">theme</code>
</td>
<td>
Optional theme to enforce for the Starlight site (e.g.,
<code>“bauhaus”</code> or <code>“ion”</code>). If <code>NULL</code>,
leaves the existing <code>customCss</code> as-is.
</td>
</tr>
</table>

## Value

Invisibly, the path to <code>site_dir</code>.
