# the manifest is stable

    Code
      cat(readLines(path, warn = FALSE, encoding = "UTF-8"), sep = "\n")
    Output
      {
        "schemaVersion": 1,
        "generator": {
          "name": "starlightdown",
          "version": "<version>"
        },
        "site": {
          "url": "https://testuser.github.io",
          "base": "/testpkg.full",
          "theme": "default"
        },
        "package": {
          "name": "testpkg.full",
          "title": "A Full-Featured Test Package for 'starlightdown'",
          "description": "A fixture package exercising the reference pipeline: Rd tag coverage, reference selectors, package Rd macros, lifecycle badges and executable examples that draw plots.",
          "version": "0.2.1",
          "license": "MIT + file LICENSE",
          "maintainer": {
            "name": "Test Author",
            "email": "test@example.com"
          },
          "urls": {
            "homepage": "https://testuser.github.io/testpkg.full/",
            "repo": "https://github.com/testuser/testpkg.full",
            "bugs": "https://github.com/testuser/testpkg.full/issues"
          }
        },
        "install": {
          "cran": null,
          "runiverse": null,
          "github": "pak::pak(\"testuser/testpkg.full\")"
        },
        "citation": {
          "text": "Author T (2026). _testpkg.full: A Full-Featured Test Package for 'starlightdown'_. R package version 0.2.1, <https://testuser.github.io/testpkg.full>.",
          "bibtex": "@Manual{,\n  title = {testpkg.full: A Full-Featured Test Package for 'starlightdown'},\n  author = {Test Author},\n  year = {2026},\n  note = {R package version 0.2.1},\n  url = {https://testuser.github.io/testpkg.full},\n}"
        },
        "quickstart": "library(testpkg.full)\nfull_add(1, 2)",
        "sidebar": [
          {
            "label": "Overview",
            "link": "/"
          },
          {
            "label": "Articles",
            "items": [
              {
                "label": "Getting started with testpkg.full",
                "link": "/articles/intro/"
              }
            ]
          },
          {
            "label": "Reference",
            "items": [
              {
                "label": "Function index",
                "link": "/reference/"
              },
              {
                "label": "full_add",
                "link": "/reference/full_add/"
              },
              {
                "label": "full_config",
                "link": "/reference/full_config/"
              },
              {
                "label": "full_describe",
                "link": "/reference/full_describe/"
              },
              {
                "label": "full_experimental",
                "link": "/reference/full_experimental/"
              },
              {
                "label": "full_plot",
                "link": "/reference/full_plot/"
              },
              {
                "label": "full_quotes",
                "link": "/reference/full_quotes/"
              },
              {
                "label": "+.fullclass",
                "link": "/reference/full_ops/"
              }
            ]
          },
          {
            "label": "What's new",
            "link": "/news/"
          }
        ],
        "topics": {
          "+.fullclass": {
            "name": "+.fullclass",
            "route": "/reference/full_ops/",
            "title": "+.fullclass",
            "summary": "Add two fullclass objects",
            "aliases": [
              "+.fullclass"
            ]
          },
          "full_add": {
            "name": "full_add",
            "route": "/reference/full_add/",
            "title": "full_add",
            "summary": "Add two numbers",
            "aliases": [
              "full_add",
              "full_plus"
            ]
          },
          "full_config": {
            "name": "full_config",
            "route": "/reference/full_config/",
            "title": "full_config",
            "summary": "Configure testpkg.full",
            "aliases": [
              "full_config"
            ]
          },
          "full_describe": {
            "name": "full_describe",
            "route": "/reference/full_describe/",
            "title": "full_describe",
            "summary": "Describe an object in one line",
            "aliases": [
              "full_describe",
              "full_describe.default"
            ]
          },
          "full_experimental": {
            "name": "full_experimental",
            "route": "/reference/full_experimental/",
            "title": "full_experimental",
            "summary": "Double a number",
            "lifecycle": "experimental",
            "aliases": [
              "full_experimental"
            ]
          },
          "full_internal": {
            "name": "full_internal",
            "route": "/reference/full_internal/",
            "title": "full_internal",
            "summary": "Internal helper",
            "aliases": [
              "full_internal"
            ]
          },
          "full_plot": {
            "name": "full_plot",
            "route": "/reference/full_plot/",
            "title": "full_plot",
            "summary": "Plot a sequence",
            "aliases": [
              "full_plot"
            ]
          },
          "full_quotes": {
            "name": "full_quotes",
            "route": "/reference/full_quotes/",
            "title": "full_quotes",
            "summary": "Find one's bearings with Ω and friends",
            "aliases": [
              "full_quotes"
            ]
          }
        },
        "redirects": {
          "/articles/intro.html": "/articles/intro/",
          "/index.html": "/",
          "/news/index.html": "/news/",
          "/reference/full_add.html": "/reference/full_add/",
          "/reference/full_config.html": "/reference/full_config/",
          "/reference/full_describe.html": "/reference/full_describe/",
          "/reference/full_experimental.html": "/reference/full_experimental/",
          "/reference/full_internal.html": "/reference/full_internal/",
          "/reference/full_ops.html": "/reference/full_ops/",
          "/reference/full_plot.html": "/reference/full_plot/",
          "/reference/full_quotes.html": "/reference/full_quotes/",
          "/reference/index.html": "/reference/"
        },
        "news": {
          "latest": "0.2.1",
          "route": "/news/",
          "versions": [
            {
              "version": "0.2.1",
              "date": "2026-08-13",
              "title": "testpkg.full 0.2.1 (2026-08-13)",
              "anchor": "testpkgfull-021-2026-08-13"
            },
            {
              "version": "0.2.0",
              "title": "testpkg.full 0.2.0",
              "anchor": "testpkgfull-020"
            }
          ]
        },
        "routes": [
          {
            "id": "index",
            "route": "/",
            "kind": "home",
            "title": "A Full-Featured Test Package for 'starlightdown'"
          },
          {
            "id": "articles/intro",
            "route": "/articles/intro/",
            "kind": "article",
            "title": "Getting started with testpkg.full"
          },
          {
            "id": "news",
            "route": "/news/",
            "kind": "news",
            "title": "Changelog"
          },
          {
            "id": "reference/index",
            "route": "/reference/",
            "kind": "reference-index",
            "title": "Function reference"
          },
          {
            "id": "reference/full_add",
            "route": "/reference/full_add/",
            "kind": "reference",
            "title": "Add two numbers"
          },
          {
            "id": "reference/full_config",
            "route": "/reference/full_config/",
            "kind": "reference",
            "title": "Configure testpkg.full"
          },
          {
            "id": "reference/full_describe",
            "route": "/reference/full_describe/",
            "kind": "reference",
            "title": "Describe an object in one line"
          },
          {
            "id": "reference/full_experimental",
            "route": "/reference/full_experimental/",
            "kind": "reference",
            "title": "Double a number"
          },
          {
            "id": "reference/full_internal",
            "route": "/reference/full_internal/",
            "kind": "reference",
            "title": "Internal helper"
          },
          {
            "id": "reference/full_ops",
            "route": "/reference/full_ops/",
            "kind": "reference",
            "title": "Add two fullclass objects"
          },
          {
            "id": "reference/full_plot",
            "route": "/reference/full_plot/",
            "kind": "reference",
            "title": "Plot a sequence"
          },
          {
            "id": "reference/full_quotes",
            "route": "/reference/full_quotes/",
            "kind": "reference",
            "title": "Find one's bearings with Ω and friends"
          }
        ]
      }

