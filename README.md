# rcontext

Code in R with a terminal agent that can actually see your session.

Claude Code and GitHub Copilot CLI run in a separate process from R, so by
default they are blind to the thing that matters most: the data frame you have
loaded, the column names it really has, and the error your last command threw.
They read your `.R` files and guess at the rest.

`rcontext` wires them into your live R session, so instead of guessing they can
look.

```
You:   my script just errored - what happened?
Agent: [reads your console history, sees the error]
       [describes penguins, finds the real column name]
       bill_length_mm doesn't exist - the column is bill_len. Line 16 should be:
       aggregate(bill_len ~ species, data = penguins, FUN = mean)
```

## Install

```r
# install.packages("remotes")
remotes::install_github("yuyaogawa9/rcontext")

rcontext::setup()
```

`setup()` shows you exactly what it will change and asks before changing
anything. Then restart R (**Session → Restart R** in RStudio) and you are done —
in this project and every other one, now and later.

Requires R >= 4.1.0. No compiler needed.

## What setup() does

Three things a package alone cannot do, because installing a package never runs
code at R startup:

1. Appends a guarded block to your `~/.Rprofile`, between markers, so every
   interactive R session registers itself:

   ```r
   # >>> rcontext >>>
   if (interactive() &&
       !nzchar(Sys.getenv("RCONTEXT_DISABLE")) &&
       requireNamespace("rcontext", quietly = TRUE)) {
     rcontext::start()
   }
   # <<< rcontext <<<
   ```

2. Registers the MCP server with each agent CLI it finds on your `PATH`, by
   calling that CLI's own command — it never edits their config files:

   ```bash
   claude  mcp add -s user rcontext -- Rscript -e "rcontext::mcp_server()"
   copilot mcp add         rcontext -- Rscript -e "rcontext::mcp_server()"
   ```

3. Installs a skill, so the agent knows *when* to use those tools. Registering
   the server alone puts five tools in front of an agent with no surrounding
   context — it will still answer from your source files, or stall on "No R
   sessions found" without knowing you simply have not restarted R yet.

   Only one of the two CLIs has a command for this, so they differ. Copilot
   registers the packaged directory, which means upgrading `rcontext` updates
   the skill in place; Claude Code has no equivalent, so the file is copied and
   refreshed on every `setup()`:

   ```bash
   copilot skill add /path/to/library/rcontext/skills
   # claude: copied to ~/.claude/skills/rcontext/SKILL.md
   ```

`rcontext::teardown()` reverses all three. Lines you wrote in `~/.Rprofile`
yourself are left exactly as they were.

To skip registration for one session: `RCONTEXT_DISABLE=1 R`.

## Try it

```r
file.copy(system.file("example", package = "rcontext"), ".", recursive = TRUE)
source("example/analysis.R")
#> Error in eval(predvars, data, env) : object 'bill_length_mm' not found
```

Now ask your agent in the terminal: *"my script just errored — what happened and
how do I fix it?"*

The fix requires a column name that appears nowhere in the script. An agent
without session context cannot get there; this one reads the error out of your
console history and the real name off the loaded data frame.

## What the agent can see

| Tool | What it answers |
|---|---|
| `describe_environment` | Every object loaded now: class, dimensions, size, columns |
| `describe_data_frame` | One table in full: column types, missing counts, first rows |
| `get_console_history` | Recent commands and their output, **including errors** |
| `run_r` | Runs code in your session, returns output/warnings/errors |
| `get_last_plot` | Saves the current plot to PNG and returns the path |

## How it works

R is single-threaded and the agent is a separate process, so the agent cannot
reach into R's memory. It can only *spawn* a process — and a freshly spawned R
is an empty session, not yours. So a broker sits in between:

```
  Claude Code / Copilot CLI
      |  stdio  (the agent spawns and owns this process)
      v
  Rscript -e rcontext::mcp_server()        <- holds no data
      |  local socket
      v
  your R session                           <- holds your data
      registered by the .Rprofile hook
```

Tools are declared in the broker but **executed in your session**. That is what
lets `get_console_history` read a log that lives in your session's memory.

One consequence is worth internalising: your session can only answer while it is
**idle at the console prompt**. If you start a ten-minute model fit by hand,
every agent query queues behind it. Let the agent run long jobs (`run_r`) rather
than running them yourself mid-conversation.

## When the socket is blocked

The broker reaches your session over a **Unix domain socket**, and some
corporate endpoint-security software blocks that silently
([mcptools#98](https://github.com/posit-dev/mcptools/issues/98)). The agent then
hangs with no error. `mcp_server(type = "http")` does **not** help: it only
changes the agent↔broker leg, and the broker↔session leg is always a UDS.

Two things to try, in order.

**1. Move the socket.** `mcptools` picks the socket path from
`MCPTOOLS_SOCKET_DIR` if it is set, falling back to a temp directory
(`/var/folders/…` on macOS, `$XDG_RUNTIME_DIR` or `/tmp/…` on Linux). If the
blocker watches those paths rather than the socket syscall itself, relocating it
is a one-line fix — add this to `~/.Rprofile` *above* the `rcontext` block:

```r
Sys.setenv(MCPTOOLS_SOCKET_DIR = "~/.rcontext-sock")
```

Use an absolute path to a directory you own, mode `0700`, not a symlink.

**2. Fall back to files.** If the socket cannot be unblocked at all, an agent
that can still read files is not stuck. Whenever the hooks are installed
(`rcontext::start()` runs them before it touches the socket, so this works even
when registration fails), the session keeps two things current under
`.rcontext/`, which `setup()` already git-ignores:

| Path | Stands in for | Refreshed |
|---|---|---|
| `.rcontext/session.md` | `describe_environment` + `get_console_history` | after every top-level command |
| `.rcontext/objects/<name>.rds` | `run_r` on real data | when you call `rcontext::export(<name>)` |

`session.md` is written automatically. Object export is deliberately manual and
per-object — it puts a copy of your data on disk:

```r
rcontext::export(model, penguins)   # -> .rcontext/objects/{model,penguins}.rds
```

The agent loads those in its own `Rscript` and analyses the copy, never
touching your session. The shipped skill tells it to read `session.md` and load
`objects/*.rds` when the MCP tools are absent, rather than reverting to
guessing from your `.R` files.

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
serve a subset instead:

```r
# everything except run_r
mcptools::mcp_server(tools = rcontext_tools()[-4])
```

The socket is local and same-user only; nothing is exposed to the network.

## Options

| Option | Default | Effect |
|---|---|---|
| `rcontext.max_lines` | 200 | Line cap on a single tool response |
| `rcontext.max_chars` | 8000 | Character cap on a single tool response |
| `rcontext.history` | 100 | Console entries retained |
| `rcontext.plot_dir` | `.rcontext/plots` | Where `get_last_plot` writes |
| `rcontext.session_file` | `.rcontext/session.md` | Where the console hook mirrors session state |
| `rcontext.object_dir` | `.rcontext/objects` | Where `export()` writes `.rds` files |

The two caps stop a large `print()` burying the agent's context window.
Responses that hit a cap say so, so the agent narrows its query instead of
assuming it saw everything.

## Troubleshooting

**"No R sessions found."** You did not restart R after `setup()`, or R was
started somewhere the `~/.Rprofile` hook does not run. Check with
`rcontext::start()` — if it registers, the hook is the problem.

**A project `.Rprofile` shadows the global one.** R runs *one* `.Rprofile`: a
project-level file replaces `~/.Rprofile` entirely. In such projects add
`if (file.exists("~/.Rprofile")) source("~/.Rprofile")` to the project file.

**The agent ignores your session and answers from source files.** It has not
loaded the skill. Agents read skills and MCP servers at startup, so quit any
agent that was already running when you ran `setup()`. Check with `copilot
skill list`, or that `~/.claude/skills/rcontext/SKILL.md` exists.

**The skill stops working after an R upgrade.** `setup()` registers an absolute
library path with Copilot, and an R minor-version upgrade relocates the
library. Re-run `rcontext::setup()`.

**The agent hangs with no error and no timeout.** Endpoint-security software is
blocking the broker↔session Unix domain socket. See
[When the socket is blocked](#when-the-socket-is-blocked): set
`MCPTOOLS_SOCKET_DIR` to move the socket, or use the `.rcontext/` file fallback.
Forcing the transport to HTTP does not help — only the broker↔session leg
matters and it is always a UDS.

**It answers about the wrong session.** Several R sessions are registered. Ask
the agent to run `list_r_sessions`, then `select_r_session`.

**Plots.** `get_last_plot` writes a PNG and returns its path. Claude Code can
open images; whether Copilot CLI can is untested — if it cannot, the path is
still useful to you.

## Credits

Built on [mcptools](https://github.com/posit-dev/mcptools) and
[ellmer](https://ellmer.tidyverse.org) by Posit. [btw](https://github.com/posit-dev/btw)
covers overlapping ground with a much larger tool set; `rcontext` deliberately
stays small and dependency-light so that it installs without a compiler.

MIT licensed.
