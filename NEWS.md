# rcontext 0.1.4

* `bridge()` / `tick()` — an opt-in, file-driven way for a coding agent to run
  R in your live session when *no* customized MCP server is allowed (some
  organisations disable them wholesale), so `run_r` is gone entirely.

  * The agent writes R to `.rcontext/command.R`. A second `addTaskCallback`
    evaluates it in your global environment the next time you run a console
    command — or when you call `tick()` — and writes the output to
    `.rcontext/result.txt`. No polling loop, no new dependency; it reuses
    `run_code(commit = TRUE)` for the evaluation and capture.

  * By default it asks y/n, showing the code, before each run. Decline and the
    command is moved to `command.R.declined` and the refusal recorded in
    `result.txt` so the agent does not wait on it. `bridge(confirm = FALSE)`
    for a session where you would rather it just run.

  * An RStudio addin, "Run queued agent command", calls `tick()` — bind it to a
    keyboard shortcut for a one-key trigger that still only fires on your
    action.

  * Supervised by construction, more than `run_r` is: it advances only on your
    action, the queued file is visible until it runs so deleting it cancels the
    command, evaluation is in `globalenv()` where effects are visible and
    reversible, and the code and its output are echoed to your console. Off
    unless you call `bridge()`; put it in `~/.Rprofile` to make it persistent.

* `.rcontext/` now keeps itself out of git: the first write drops a `*`
  `.gitignore` into it. Earlier docs claimed `setup()` did this — it never did;
  the entry only ever existed in this package's own repo. Wording corrected.

# rcontext 0.1.3

* A file-based fallback for when endpoint security blocks the local socket the
  broker uses to reach the session. There is then no live channel left, but an
  agent can still read files in the project.

  * The console hook now also rewrites `.rcontext/session.md` after every
    top-level command — the environment summary and recent console history,
    including errors — for an agent whose `rcontext` MCP tools are missing to
    read directly. `rcontext::start()` installs the hook before it touches the
    socket, so the snapshot is kept current even when registration fails.

  * `export()` writes one `.rds` per named object into `.rcontext/objects/`, so
    an agent can `readRDS()` and analyse a copy in its own process without a
    live session. Object selection is explicit and never automatic; objects
    over `max_size` (50 MB) are skipped.

  * The shipped skill gains a section telling the agent to read `session.md`
    and load `objects/*.rds` when the tools are absent, instead of reverting to
    guessing from `.R` files.

* README: the old "force TCP on both sides" troubleshooting note was wrong —
  `mcp_server(type = "http")` only changes the agent-to-broker leg, and the
  broker-to-session leg is always a Unix domain socket. Corrected, and
  `MCPTOOLS_SOCKET_DIR` (which relocates that socket) is now documented as the
  first mitigation to try, alongside the file fallback.

# rcontext 0.1.2

* `setup()` now installs an agent skill alongside the MCP server. Registering
  the server put five tools in front of the agent with no surrounding context,
  which is not the same as the agent knowing when to reach for them: agents
  answered from source files, or stalled on "No R sessions found" without
  knowing the user had simply not restarted R. The skill covers tool selection,
  picking between several registered sessions, `run_r`'s scratch-environment
  semantics, the idle-session constraint, and that troubleshooting path.

* The two CLIs take the skill differently, because only one has a command for
  it. `copilot skill add` registers the packaged directory, so upgrading
  `rcontext` updates the skill in place. Claude Code has no equivalent command,
  so the file is copied into `~/.claude/skills/` and refreshed on every
  `setup()`.

* `teardown()` removes the skill. `setup()` and `teardown()` gain a
  `claude_dir` argument, exposed for testing exactly as `rprofile` is.

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
