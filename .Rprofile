# Registers this R session with the MCP broker so a terminal coding agent
# (Claude Code / GitHub Copilot CLI) can see your environment and console.
#
# Guarded on purpose: if mcptools is not installed yet, startup stays silent
# and clean instead of erroring on every new session. Run setup.R to install.

if (interactive() && requireNamespace("mcptools", quietly = TRUE)) {
  source("R/agent_tools.R")
  agent_start_logging()
  mcptools::mcp_session()
}

# NOTE: a project .Rprofile overrides your personal ~/.Rprofile entirely.
# If you have startup customizations you want here too, add this line above:
#   if (file.exists("~/.Rprofile")) source("~/.Rprofile")
