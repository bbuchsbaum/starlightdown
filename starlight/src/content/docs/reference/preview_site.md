---
title: 'Run npm run dev for the Starlight site'
---

## Description

Convenience wrapper around <code style="white-space: pre;">npm run
dev</code> in the Starlight project. You must have run
<code style="white-space: pre;">npm install</code> in
<code>site_dir</code> first.

## Usage

<pre><code class='language-R'>preview_site(path = ".", site_dir = "starlight", npm_args = c("run", "dev"))
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
<code id="npm_args">npm_args</code>
</td>
<td>
Character vector of arguments passed to <code>npm</code>. Defaults to
<code>c(“run”, “dev”)</code>.
</td>
</tr>
</table>

## Value

Invisibly, the exit status of the npm command.
