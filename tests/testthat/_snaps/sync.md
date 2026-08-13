# a redirect stub is a meta-refresh page with the base applied

    Code
      cat(sd_redirect_html("/reference/add_one/", fake_pkg()))
    Output
      <!doctype html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <title>Redirecting to /testpkg/reference/add_one/</title>
      <meta http-equiv="refresh" content="0; url=/testpkg/reference/add_one/">
      <meta name="robots" content="noindex">
      <link rel="canonical" href="https://example.github.io/testpkg/reference/add_one/">
      </head>
      <body>
      <p>This page moved to <a href="/testpkg/reference/add_one/">/testpkg/reference/add_one/</a>.</p>
      </body>
      </html>

