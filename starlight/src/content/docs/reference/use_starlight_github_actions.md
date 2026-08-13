---
title: 'Set up a GitHub Actions workflow for Starlight docs'
---

## Description

Copies a minimal workflow that builds the Starlight site with
<code>build_site()</code> and deploys
<code style="white-space: pre;">starlight/dist/</code> to GitHub Pages.

## Usage

<pre><code class='language-R'>use_starlight_github_actions(
  branch = "main",
  dist_dir = "starlight/dist",
  overwrite = FALSE
)
</code></pre>

## Arguments

<table role="presentation">
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="branch">branch</code>
</td>
<td>
Git branch to publish from (default: <code>“main”</code>).
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="dist_dir">dist_dir</code>
</td>
<td>
Path to the built Starlight output (default:
<code>“starlight/dist”</code>).
</td>
</tr>
<tr>
<td style="white-space: collapse; font-family: monospace; vertical-align: top">
<code id="overwrite">overwrite</code>
</td>
<td>
Whether to overwrite an existing workflow file.
</td>
</tr>
</table>

## Value

Invisibly, the path to the workflow file.
