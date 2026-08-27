# ellmer tool definitions ------------------------------------------------------

#' Tools exposed to the coding agent
#'
#' Returns the list of [ellmer::tool()] definitions that [mcp_server()] serves.
#' Exported so you can compose your own server, or add these to an existing
#' `ellmer` chat client.
#'
#' Tool descriptions are written for the agent, not for you: they say when to
#' reach for each tool, because a tool an agent does not know when to call is
#' the same as one that is not there.
#'
#' @return A list of `ellmer::tool()` objects.
#' @export
#' @examples
#' \dontrun{
#' # serve a subset yourself
#' mcptools::mcp_server(tools = rcontext_tools()[1:2])
#' }
rcontext_tools <- function() {
  list(
    ellmer::tool(
      function() describe_env(),
      name = "describe_environment",
      description = paste(
        "List every object currently loaded in the user's R global environment,",
        "with its class, dimensions and size, and the column names of any data",
        "frames. Call this first when the user refers to their data, a variable,",
        "or 'my data frame' without saying what is in it."
      ),
      arguments = list()
    ),

    ellmer::tool(
      function(name, n = 5L) describe_df(name, n),
      name = "describe_data_frame",
      description = paste(
        "Show the structure of one data frame in the user's session: dimensions,",
        "every column with its type and missing count, and the first few rows.",
        "Use this before writing code that references columns, so you use the",
        "real column names rather than guessing."
      ),
      arguments = list(
        name = ellmer::type_string("Name of the data frame in the global environment."),
        n = ellmer::type_integer("How many rows to show. Default 5.", required = FALSE)
      )
    ),

    ellmer::tool(
      function(n = 20L) console_history(n),
      name = "get_console_history",
      description = paste(
        "Recent commands the user ran in their R console and the output they",
        "produced, including error messages. Call this when the user mentions",
        "something failed, errored or 'just broke' -- the error text and the",
        "command that caused it are here, not in their script."
      ),
      arguments = list(
        n = ellmer::type_integer("How many recent entries to return. Default 20.",
                                 required = FALSE)
      )
    ),

    ellmer::tool(
      function(code, commit = FALSE) run_code(code, commit),
      name = "run_r",
      description = paste(
        "Evaluate R code in the user's live session and return printed output,",
        "warnings, messages and errors. Assignments go to a scratch environment",
        "and do NOT modify the user's global environment; reads of existing",
        "objects work normally. Pass commit = TRUE only when the user has asked",
        "for the result to be kept in their session."
      ),
      arguments = list(
        code = ellmer::type_string("R code to evaluate."),
        commit = ellmer::type_boolean(
          "TRUE to assign into the global environment instead of the scratch environment.",
          required = FALSE
        )
      )
    ),

    ellmer::tool(
      function() last_plot_png(),
      name = "get_last_plot",
      description = paste(
        "Save the plot currently displayed in the user's IDE to a PNG file and",
        "return the file path, so it can be opened and looked at. Use when the",
        "user asks about a plot they can see and you cannot."
      ),
      arguments = list()
    )
  )
}
