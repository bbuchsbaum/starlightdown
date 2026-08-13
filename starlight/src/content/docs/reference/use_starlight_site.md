---
title: 'Scaffold an Astro Starlight project for this package'
---

## Description

This creates a <code style="white-space: pre;">starlight/</code>
directory containing a minimal Astro + Starlight project which will
serve your package docs.

## Usage

<pre><code class='language-R'>use_starlight_site(
  path = ".",
  site_dir = "starlight",
  overwrite = FALSE,
  theme = c("bauhaus", "ion")
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
Subdirectory where the Starlight project will live.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="overwrite">overwrite</code>
</td>
<td>
Whether to overwrite an existing directory at <code>site_dir</code>.
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="theme">theme</code>
</td>
<td>
Starlight theme to apply (<code>“bauhaus”</code> default, or
<code>“ion”</code>).
</td>
</tr>
</table>

## Value

Invisibly, the path to <code>site_dir</code>.
