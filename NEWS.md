# rcontext 0.1.1

* `setup()` and `teardown()` failed to register with either agent CLI.
  `system2()` does not quote its arguments, so the shell read the parentheses
  in `rcontext::mcp_server()` as syntax and errored. Arguments are now passed
  through `shQuote()`.
* The fallback command printed when registration fails carried the same
  defect, so copying it also failed. It is now shell-safe.

# rcontext 0.1.0

First release. Converted from the `r-agent-context` project template into an
installable package.

* `setup()` / `teardown()` — one-time, consent-gated configuration. Writes a
  marker-delimited block to `~/.Rprofile` and registers the MCP server with
  every agent CLI found on `PATH`, using each CLI's own `mcp add` command.
* `start()` / `stop_session()` — per-session registration, idempotent.
* `mcp_server()` — broker entry point. Resolves through the installed package,
  so an agent can be started from any working directory.
* `rcontext_tools()` — five tools: `describe_environment`,
  `describe_data_frame`, `get_console_history`, `run_r`, `get_last_plot`.

Notes on the conversion:

* `btw` is no longer a dependency. Its environment tools are reimplemented in
  `R/env.R`; its documentation and file tools are not, because coding agents
  already read files and search code natively. This drops `dplyr`,
  `rmarkdown`, `xml2`, `S7`, `skimr` and `frontmatter` -> `yaml12` from the
  install, the last of which needs a Rust toolchain wherever CRAN has no
  binary. It also lowers the R floor from 4.2.0 to 4.1.0.
* Agent registration is now user-scoped rather than per-project, so a single
  `setup()` covers every project on the machine.
