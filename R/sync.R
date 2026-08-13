# Staging and commit ---------------------------------------------------------
#
# The content tree is built somewhere else and swapped in whole. Two
# consequences follow, both of them the point: a build that fails validation
# never touches the live site, and a page whose source was deleted cannot
# survive as a stale file, because the directory it lived in is replaced rather
# than written over.
#
# Staging happens inside the site's own machine-owned directory rather than the
# user cache, so the swap is a rename on one filesystem. A cache directory can
# easily be on another volume, where rename() fails and the "atomic" swap
# quietly degrades into a copy.

#' Path of the staging root for a site
#'
#' Suffixed per process: two builds of the same site otherwise share one
#' staging directory, and the second one's `unlink()` deletes the first one's
#' work out from under it.
#' @noRd
sd_stage_dir <- function(site_path, token = sd_commit_token()) {
  fs::path(site_path, ".starlightdown", "stage", token)
}

#' Create an empty staging tree
#'
#' @return `list(root, content, public)`.
#' @noRd
sd_new_stage <- function(site_path) {
  root <- sd_stage_dir(site_path)
  unlink(root, recursive = TRUE)
  content <- fs::path(root, "content")
  public <- fs::path(root, "public")
  fs::dir_create(content)
  fs::dir_create(public)
  list(root = as.character(root), content = as.character(content), public = as.character(public))
}

# Remove this build's staging directory, and the shared parent once the last
# concurrent build has finished with it.
#' @noRd
sd_discard_stage <- function(root) {
  unlink(root, recursive = TRUE)
  parent <- fs::path_dir(root)
  if (fs::dir_exists(parent) && !length(fs::dir_ls(parent, all = TRUE))) {
    try(fs::dir_delete(parent), silent = TRUE)
  }
  invisible(root)
}

#' Swap a staged directory into place
#'
#' The live directory is moved aside first and only deleted once the new one is
#' in place, so a failure mid-swap can be rolled back.
#'
#' @param stage Directory holding the new content.
#' @param live Directory to replace.
#' @noRd
sd_commit_dir <- function(stage, live) {
  fs::dir_create(fs::path_dir(live))
  retired <- paste0(live, ".sd-old-", sd_commit_token())

  had_live <- fs::dir_exists(live)
  if (had_live && !sd_move(live, retired)) {
    cli::cli_abort("Could not move {.path {live}} aside to commit the new build.")
  }

  if (!sd_move(stage, live)) {
    # Put the old tree back rather than leaving the site with no content.
    if (had_live) {
      sd_move(retired, live)
    }
    cli::cli_abort("Could not move the staged build into {.path {live}}.")
  }

  if (had_live) {
    unlink(retired, recursive = TRUE)
  }
  invisible(live)
}

#' Merge a staged subtree into a live directory, replacing only what it owns
#'
#' `public/` is user territory apart from the redirect stubs we put there, so
#' it is merged rather than swapped: previously generated stubs are removed,
#' then the new ones are copied in.
#' @noRd
sd_commit_public <- function(stage_public, live_public, previous = character()) {
  fs::dir_create(live_public)

  emptied <- character()
  for (rel in previous) {
    # `previous` comes from our own inventory, but it lands in fs::file_delete,
    # so it is re-checked here rather than trusted.
    safe <- sd_redirect_output_path(rel)
    if (is.na(safe)) {
      next
    }
    old <- fs::path(live_public, safe)
    if (fs::file_exists(old)) {
      fs::file_delete(old)
      emptied <- c(emptied, as.character(fs::path_dir(old)))
    }
  }
  sd_prune_empty_dirs(unique(emptied), live_public)

  files <- fs::dir_ls(stage_public, recurse = TRUE, type = "file")
  written <- character()
  for (file in files) {
    rel <- as.character(fs::path_rel(file, stage_public))
    target <- fs::path(live_public, rel)
    fs::dir_create(fs::path_dir(target))
    fs::file_copy(file, target, overwrite = TRUE)
    written <- c(written, rel)
  }
  invisible(written)
}

# Only directories a removal actually emptied, and never public/ itself:
# everything else under public/ is the user's.
#' @noRd
sd_prune_empty_dirs <- function(dirs, root) {
  root <- as.character(fs::path_abs(root))
  # Deepest first, so a directory emptied by pruning its children also goes.
  dirs <- dirs[order(-nchar(dirs), method = "radix")]
  for (dir in dirs) {
    absolute <- as.character(fs::path_abs(dir))
    while (nzchar(absolute) && absolute != root && startsWith(absolute, root)) {
      if (!fs::dir_exists(absolute) || length(fs::dir_ls(absolute, all = TRUE))) {
        break
      }
      fs::dir_delete(absolute)
      absolute <- as.character(fs::path_dir(absolute))
    }
  }
  invisible(root)
}

# rename() only works within a filesystem. Falling back to copy-then-delete
# keeps the build correct on the machines where it does not.
#' @noRd
sd_move <- function(from, to) {
  moved <- tryCatch(
    {
      file.rename(from, to)
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  if (isTRUE(moved)) {
    return(TRUE)
  }

  copied <- tryCatch(
    {
      # `overwrite = TRUE` *merges* into an existing directory, which on the
      # rollback path would union the old tree with a half-written new one.
      # A move replaces.
      unlink(to, recursive = TRUE)
      fs::dir_copy(from, to)
      TRUE
    },
    error = function(e) FALSE
  )
  if (!copied) {
    return(FALSE)
  }
  unlink(from, recursive = TRUE)
  TRUE
}

#' @noRd
sd_commit_token <- function() {
  paste0(Sys.getpid(), "-", sample.int(1e6L, 1L))
}
