# Environment inspection -------------------------------------------------------
#
# These replace btw's env tools. Reimplemented rather than depended upon: btw
# pulls dplyr, rmarkdown, xml2, S7, skimr and frontmatter -> yaml12, and yaml12
# needs a Rust toolchain to build wherever CRAN has no binary. For a package
# whose whole pitch is "it just installs", that dependency chain is the product.

#' One-line summary of every object in the global environment
#' @noRd
describe_env <- function() {
  objs <- ls(globalenv())
  if (length(objs) == 0L) {
    return("The global environment is empty -- nothing is loaded yet.")
  }

  rows <- vapply(objs, function(nm) {
    x <- get(nm, envir = globalenv())

    cls <- paste(class(x), collapse = "/")
    shape <- if (!is.null(dim(x))) {
      paste(dim(x), collapse = " x ")
    } else if (is.function(x)) {
      ""
    } else {
      paste0("length ", length(x))
    }
    size <- format(utils::object.size(x), units = "auto")

    cols <- if (is.data.frame(x)) {
      paste0("\n    columns: ", paste(names(x), collapse = ", "))
    } else {
      ""
    }

    sprintf("  %s  <%s>  %s  [%s]%s", nm, cls, shape, size, cols)
  }, character(1), USE.NAMES = FALSE)

  truncate_output(c(
    sprintf("%d object(s) in the global environment:", length(objs)),
    rows,
    "",
    "Use describe_data_frame(name) for the full structure of a table."
  ))
}

#' Column-level detail for one data frame
#' @noRd
describe_df <- function(name, n = 5L) {
  if (!is.character(name) || length(name) != 1L) {
    return("Pass the name of the object as a single string.")
  }
  if (!exists(name, envir = globalenv(), inherits = FALSE)) {
    return(sprintf(
      "No object named '%s' in the global environment. Use describe_environment to see what is loaded.",
      name
    ))
  }

  x <- get(name, envir = globalenv())
  if (!is.data.frame(x)) {
    return(sprintf(
      "'%s' is not a data frame (it is <%s>). Use run_r to inspect it.",
      name, paste(class(x), collapse = "/")
    ))
  }

  # unique counts are genuinely useful for telling categorical from continuous,
  # but not worth a full scan of a very large table on every call
  count_unique <- nrow(x) <= 50000L

  cols <- vapply(names(x), function(cn) {
    col <- x[[cn]]
    type <- paste(class(col), collapse = "/")
    na <- sum(is.na(col))
    uniq <- if (count_unique) sprintf(", %d unique", length(unique(col))) else ""
    sprintf("  %s  <%s>  %d missing%s", cn, type, na, uniq)
  }, character(1), USE.NAMES = FALSE)

  head_txt <- utils::capture.output(print(utils::head(as.data.frame(x), n)))

  truncate_output(c(
    sprintf("%s: %d rows x %d columns", name, nrow(x), ncol(x)),
    "",
    "Columns:",
    cols,
    "",
    sprintf("First %d rows:", min(n, nrow(x))),
    head_txt
  ))
}
