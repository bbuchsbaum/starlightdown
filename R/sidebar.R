# Sidebar --------------------------------------------------------------------
#
# The sidebar travels as data in `site.json`, never as generated JavaScript:
# that is what makes a label containing an apostrophe a non-event. Links are
# base-less, because Starlight applies the base itself (CONTRACT.md §5).

#' Build the Starlight sidebar
#'
#' @param pkg An `sd_pkg()` object.
#' @param routes The route records produced by the builders.
#' @return A list in Starlight's sidebar shape.
#' @noRd
sd_sidebar <- function(pkg, routes) {
  items <- list(list(label = "Overview", link = "/"))

  articles <- sd_sidebar_articles(pkg, routes)
  if (length(articles)) {
    items[[length(items) + 1L]] <- list(label = "Articles", items = articles)
  }

  reference <- sd_sidebar_reference(pkg, routes)
  if (length(reference)) {
    items[[length(items) + 1L]] <- list(label = "Reference", items = reference)
  }

  if (length(sd_routes_of_kind(routes, "news"))) {
    items[[length(items) + 1L]] <- list(label = "What's new", link = "/news/")
  }

  items
}

#' @noRd
sd_routes_of_kind <- function(routes, kind) {
  Filter(function(r) identical(r$kind, kind), routes)
}

# Articles follow the order of the `articles:` sections in _pkgdown.yml, then
# anything the config forgot, so a curated order is honoured but nothing goes
# missing.
#' @noRd
sd_sidebar_articles <- function(pkg, routes) {
  articles <- sd_routes_of_kind(routes, "article")
  if (!length(articles)) {
    return(list())
  }
  by_name <- articles
  names(by_name) <- vapply(articles, function(r) r$name, character(1))

  ordered <- character()
  for (section in pkg$meta$articles) {
    wanted <- sd_selector_entries(section$contents, section = section$title)
    ordered <- union(ordered, intersect(wanted, names(by_name)))
  }
  ordered <- union(ordered, names(by_name))

  unname(lapply(by_name[ordered], function(r) {
    list(label = r$title, link = r$route)
  }))
}

# The index first, then every public topic in the order the reference sections
# resolve to. Internal topics have pages so links resolve, but listing them
# would advertise an API the author did not mean to publish.
#' @noRd
sd_sidebar_reference <- function(pkg, routes) {
  topics <- sd_routes_of_kind(routes, "reference")
  topics <- Filter(function(r) !isTRUE(r$internal), topics)
  index <- sd_routes_of_kind(routes, "reference-index")
  if (!length(topics) && !length(index)) {
    return(list())
  }

  items <- list()
  if (length(index)) {
    items[[length(items) + 1L]] <- list(
      label = "Function index",
      link = index[[1L]]$route
    )
  }

  by_name <- topics
  names(by_name) <- vapply(topics, function(r) r$name, character(1))

  ordered <- character()
  for (section in pkg$meta$reference) {
    selected <- sd_select_topics(section$contents, pkg$topics, section = section$title)
    ordered <- union(ordered, intersect(selected, names(by_name)))
  }
  ordered <- union(ordered, names(by_name))

  for (r in by_name[ordered]) {
    items[[length(items) + 1L]] <- list(label = r$name, link = r$route)
  }

  items
}
