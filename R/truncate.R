# Output shaping ---------------------------------------------------------------

#' Cap tool output
#'
#' Truncates to the configured line and character limits, appending an explicit
#' notice when either applies. The notice matters as much as the cap: without
#' it an agent reads a truncated result as a complete one.
#'
#' @param x Character vector; collapsed with newlines.
#' @param max_lines,max_chars Limits; default to the package options.
#' @return A single string.
#' @noRd
truncate_output <- function(x,
                            max_lines = opt_max_lines(),
                            max_chars = opt_max_chars()) {
  txt <- paste(x, collapse = "\n")
  if (!nzchar(txt)) return("")

  lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
  notes <- character(0)

  if (length(lines) > max_lines) {
    notes <- sprintf("... [%d more lines truncated]", length(lines) - max_lines)
    lines <- lines[seq_len(max_lines)]
  }

  out <- paste(lines, collapse = "\n")
  if (nchar(out) > max_chars) {
    out <- substr(out, 1L, max_chars)
    notes <- c(notes, sprintf("... [truncated at %d characters]", max_chars))
  }

  paste(c(out, notes), collapse = "\n")
}
