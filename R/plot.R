# Plot capture -----------------------------------------------------------------

#' Write the current plot to PNG and return its path
#'
#' Writes inside the working directory rather than `tempdir()`, because some
#' agents cannot open files outside the project they were started in.
#'
#' @noRd
last_plot_png <- function() {
  if (is.null(grDevices::dev.list())) {
    return("No active plot device -- draw a plot first.")
  }

  dir <- opt_plot_dir()
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  path <- file.path(dir, format(Sys.time(), "plot-%Y%m%d-%H%M%S.png"))

  ok <- tryCatch({
    grDevices::dev.copy(grDevices::png, filename = path,
                        width = 1000, height = 700, res = 120)
    grDevices::dev.off()
    TRUE
  }, error = function(e) FALSE)

  if (!ok || !file.exists(path)) {
    "Could not copy the current plot device."
  } else {
    normalizePath(path)
  }
}
