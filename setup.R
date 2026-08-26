# setup.R ---------------------------------------------------------------------
# Run once, from the project root:   Rscript setup.R   (or source() it in RStudio)
# Safe to re-run.

cat("\nr-agent-context setup\n---------------------\n\n")

fail <- function(...) { cat("FAIL  ", ..., "\n", sep = ""); quit(status = 1L) }
warn <- function(...) cat("WARN  ", ..., "\n", sep = "")
good <- function(...) cat("ok    ", ..., "\n", sep = "")

# 1. R version -----------------------------------------------------------------
# btw requires R >= 4.2.0; it is the binding constraint of the three.
if (getRversion() < "4.2.0") {
  fail("R ", as.character(getRversion()), " is too old. btw requires R >= 4.2.0.")
}
good("R ", as.character(getRversion()))

# 2. Working directory ---------------------------------------------------------
if (!file.exists("R/agent_tools.R")) {
  fail("Run this from the repo root (R/agent_tools.R not found here).")
}
good("running from the repo root")

# 3. Personal .Rprofile collision ----------------------------------------------
# A project .Rprofile silently replaces the user's own. Warn rather than guess.
if (file.exists("~/.Rprofile")) {
  warn("You have a personal ~/.Rprofile. This project's .Rprofile overrides it.")
  warn("To keep both, add this as the first line of ./.Rprofile:")
  warn('  if (file.exists("~/.Rprofile")) source("~/.Rprofile")')
}

# 4. Packages ------------------------------------------------------------------
needed  <- c("ellmer", "btw", "mcptools")
missing <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing)) {
  cat("\ninstalling: ", paste(missing, collapse = ", "), "\n\n", sep = "")
  install.packages(missing, repos = "https://cloud.r-project.org")
  still <- missing[!vapply(missing, requireNamespace, logical(1), quietly = TRUE)]
  if (length(still)) fail("could not install: ", paste(still, collapse = ", "))
}
for (p in needed) good(p, " ", as.character(packageVersion(p)))

if (packageVersion("ellmer") < "0.3.0") {
  fail("ellmer ", as.character(packageVersion("ellmer")),
       " is too old -- tool() changed signature in 0.3.0. Update ellmer.")
}

# 5. Tools construct -----------------------------------------------------------
source("R/agent_tools.R")
tools <- tryCatch(agent_tools(), error = function(e) {
  fail("agent_tools() failed to build: ", conditionMessage(e))
})
good(length(tools), " custom tools defined")

# 6. Next steps ----------------------------------------------------------------
cat("\nNext:\n")
cat("  1. Restart R (Session > Restart R) so .Rprofile registers this session.\n")
cat("  2. In the RStudio Terminal, from this directory, start your agent:\n")
cat("       claude        # reads .mcp.json\n")
cat("       copilot       # reads .github/mcp.json\n")
cat("  3. Ask it: \"what data frames do I have loaded?\"\n\n")
cat("  Then try the demo:  source(\"example/analysis.R\")  -- it fails on purpose.\n\n")
