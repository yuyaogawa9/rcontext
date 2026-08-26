# r-agent-context

Code in R with a terminal agent that can actually see your session.

Claude Code and GitHub Copilot CLI run in a separate process from R, so by
default they are blind to the thing that matters most: the data frame you have
loaded, the column names it really has, and the error your last command threw.
They read your `.R` files and guess at the rest.

This template wires them into your live RStudio session, so instead of guessing
they can look.

```
You:   my script just errored - what happened?
Agent: [reads your console history, sees the error]
       [describes penguins, finds the real column name]
       bill_length_mm doesn't exist - the column is bill_len. Line 16 should be:
       aggregate(bill_len ~ species, data = penguins, FUN = mean)
```

## Quickstart

```bash
git clone https://github.com/yuyaogawa9/r-agent-context.git
cd r-agent-context
```

1. Open `r-agent-context.Rproj` in RStudio.
2. In the R console: `source("setup.R")` — installs `mcptools`, `btw`, `ellmer`
   and runs a preflight check.
3. **Session → Restart R.** The `.Rprofile` registers your session on startup,
   so this step is required, not optional.
4. Open the RStudio **Terminal** tab and start an agent from the project root:
   - `claude` — reads `.mcp.json`
   - `copilot` — reads `.github/mcp.json`
5. Ask it: *"what data frames do I have loaded?"*

Requires R >= 4.2.0.

## Try the demo

`example/analysis.R` is broken on purpose. In the R console:

```r
source("example/analysis.R")
#> Error in eval(predvars, data, env) : object 'bill_length_mm' not found
```

Now ask your agent in the terminal: *"my script just errored — what happened
and how do I fix it?"*

The fix requires knowing a column name that appears nowhere in the script.
An agent without session context cannot get there; this one reads the error
out of your console history and the real name off the loaded data frame.

## What the agent can see

| Tool | What it answers |
|---|---|
| `get_console_history` | Recent commands and their output, **including errors** |
| `run_r` | Runs code in your session, returns output/warnings/errors |
| `get_last_plot` | Saves the current plot to PNG and returns the path |
| `btw_tool_env_describe_environment` | What objects are loaded right now |
| `btw_tool_env_describe_data_frame` | Columns, types, dimensions, sample rows |
| `btw_tool_sessioninfo_*` | R version, platform, installed packages |
| `btw_tool_docs_*` | Help pages and vignettes for installed packages |
| `list_r_sessions` / `select_r_session` | Which session to target when several are open |

The first three are defined in `R/agent_tools.R`; the rest come from
[btw](https://posit-dev.github.io/btw/) and
[mcptools](https://posit-dev.github.io/mcptools/).

## How it works

R is single-threaded and the agent is a separate process, so the agent cannot
reach into R's memory. It can only *spawn* a process — and a freshly spawned R
is an empty session, not yours. So a broker sits in between:

```
  Claude Code / Copilot CLI
      |  stdio  (the agent spawns and owns this process)
      v
  Rscript -e mcptools::mcp_server(...)        <- holds no data
      |  local socket
      v
  your RStudio session                        <- holds your data
      registered by .Rprofile on startup
```

Tools are declared in the broker but **executed in your session**. That is what
lets `get_console_history` read a log that lives in your session's memory.

One consequence is worth internalising: your session can only answer while it
is **idle at the console prompt**. If you start a ten-minute model fit by hand,
every agent query queues behind it. Let the agent run long jobs (`run_r`)
rather than running them yourself mid-conversation.

## Security — read this

`run_r` gives a language model the ability to execute arbitrary R code inside
your live session.

By default it evaluates in a scratch environment whose parent is `globalenv()`:
reads of your real objects work normally, but assignments land in the scratch
environment instead of overwriting your globals. `commit = TRUE` opts into
writing to the global environment.

**That scratch environment is a guard against accidents, not a security
boundary.** `<<-`, `assign(envir = globalenv())`, `file.remove()`, `system()`
and any file I/O escape it trivially. If you are not comfortable granting that,
delete the `run_r` entry from `agent_tools()` in `R/agent_tools.R` — the
inspection tools work without it.

The socket is local and same-user only; nothing is exposed to the network.

## Using this in your own project

Only two files matter. Copy them into any existing R project:

- `R/agent_tools.R` — the tools
- `.Rprofile` — registers the session and loads them

then copy `.mcp.json` (Claude Code) and/or `.github/mcp.json` (Copilot CLI) and
run `setup.R` once. Cloning this repo is the demo; the two files are the thing.

Two configs rather than one because the schemas collide: Claude Code reads an
entry with no `type` key as stdio, while Copilot CLI requires `"type": "local"`.

## Troubleshooting

**The agent hangs with no error and no timeout.** Most likely cause, and the
first thing to try. `mcptools` connects over Unix domain sockets, which some
endpoint-security software blocks silently
([mcptools#98](https://github.com/posit-dev/mcptools/issues/98)). Force TCP on
both sides — in `.Rprofile` before `mcp_session()`, and in the `-e` string in
your MCP config:

```r
the_env$socket_url <- "tcp://127.0.0.1:4777"
```

**"No R sessions found."** You did not restart R after `setup.R` (step 3), or
you started the agent from a different directory than the project root.

**It answers about the wrong session.** Several RStudio projects are open and
each registered. Ask the agent to run `list_r_sessions`, then `select_r_session`.

**My personal `.Rprofile` stopped applying.** A project `.Rprofile` replaces it
entirely. Add `if (file.exists("~/.Rprofile")) source("~/.Rprofile")` as the
first line of this project's `.Rprofile`.

**`could not find function "agent_tools"`.** The broker is resolving
`R/agent_tools.R` relative to its working directory. Start the agent from the
project root, or make the path in the MCP config absolute.

**Plots.** `get_last_plot` writes a PNG and returns its path. Claude Code can
open images; whether Copilot CLI can is untested — if it cannot, the path is
still useful to you.

## Status

`R/agent_tools.R` has a test suite covering output truncation, console history,
the sandbox boundary, and error/warning capture:

```bash
Rscript tests/test_agent_tools.R
```

These run without an agent, an MCP server, or RStudio. The bridge itself
depends on `mcptools` behaviour upstream and is exercised by the demo above
rather than by automated tests.

## Credits

Built on [mcptools](https://github.com/posit-dev/mcptools) and
[btw](https://github.com/posit-dev/btw) by Posit. If you want a richer,
RStudio-specific alternative with async execution and viewer capture, look at
[ClaudeR](https://github.com/IMNMV/ClaudeR).

MIT licensed.
