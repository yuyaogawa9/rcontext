---
name: rcontext
description: Read and run code in the user's live R session - loaded objects, real data frame columns, console history including errors, and the current plot. Use whenever the user asks about "my data", "my session", "my environment", a variable or data frame they have loaded, an R error they just hit, or wants R code run against their real data. Also use when an R tool returns "No R sessions found".
---

# rcontext: the user has a live R session you can read

The user is running R (usually in RStudio) in a **separate process** from you.
The `rcontext` MCP server connects you to that session, so you can read what is
actually loaded instead of inferring it from `.R` files.

Use it. A running R session is the ground truth; the script on disk is a guess
about what the session contains.

## Which tool answers which question

| The user says | Call |
|---|---|
| "my data", "what have I got loaded?", "my environment" | `describe_environment` |
| names a table, or you are about to write code touching columns | `describe_data_frame` |
| "it errored", "that broke", "what happened?" | `get_console_history` |
| wants something computed, checked, or tried | `run_r` |
| "my plot", "does this chart look right?" | `get_last_plot` |

## Rules that matter

**Never guess a column name.** If you are about to write code that references
columns, call `describe_data_frame` first. The whole reason this server exists
is that scripts refer to columns the data does not have — the script says
`bill_length_mm`, the loaded frame has `bill_len`. Reading the file cannot
catch that; reading the session can.

**Errors live in the session, not the file.** When the user says something
broke, `get_console_history` has the command and the error text. Do not ask
them to paste it.

**Check which session you are attached to.** If more than one R session is
registered, call `list_r_sessions`, and `select_r_session` if the objects do
not match what the user is describing. Answering confidently about the wrong
session is the most likely way to mislead them.

**`run_r` does not modify their globals by default.** Assignments land in a
scratch environment; reads of existing objects work normally. Pass
`commit = TRUE` only when the user has asked for a result to be kept in their
session. Say so when you do.

`run_r` executes arbitrary code in a live session holding the user's real work.
Treat destructive operations — `rm()`, `file.remove()`, `system()`, overwriting
a loaded object — as needing explicit consent, not inference.

**The session only answers while idle at the console prompt.** R is
single-threaded. If the user is running something long by hand, your calls
queue behind it. Prefer running long jobs yourself with `run_r` over asking
them to run it and report back.

**Truncated means truncated.** Responses are capped and say so when they hit
the cap. A truncation notice means narrow the query — filter, select fewer
columns, ask for fewer rows — not that you have seen everything there is.

**Editing a file does not update the session.** After you change a script, the
objects in memory still reflect the old code. Ask the user to re-run or
re-`source()` it, or run it yourself with `run_r`, before checking whether the
fix worked.

## Reading the output

`describe_data_frame` reports missing values as `is.na()` counts. `Inf`,
`-Inf`, `NaN` and empty strings are **not** counted as missing, so a column can
read "0 missing" and still be unusable. If numbers look wrong, inspect the
column directly with `run_r` rather than trusting the summary.

## If no session is found

"No R sessions found" does not mean the setup is broken. In order of
likelihood:

1. **The user has not restarted R since running `rcontext::setup()`.** The
   registration hook runs at R startup. Ask them to restart R.
2. **A project-level `.Rprofile` is shadowing `~/.Rprofile`.** R runs only one:
   a project file replaces the global one entirely. Fix by adding
   `if (file.exists("~/.Rprofile")) source("~/.Rprofile")` to the project file.
3. **The session was never registered.** Have them run `rcontext::start()` in
   the R console; if that works, the startup hook is the problem, not the
   server.

Tell them which of these to check. Do not silently fall back to reading their
source files and answering as if you had seen the session — say that you could
not reach it.
