## ADSL Explorer — shinychat + otel demo ---------------------------------------
##
## A Shiny application demonstrating the {shinychat} package for LLM-powered
## chat and {otel} for OpenTelemetry instrumentation, using clinical trial
## data from {random.cdisc.data}.
##
## Architecture:
##   * shinychat + ellmer provide the chat interface and LLM communication
##   * Manual Shiny filter controls (ARM, AGE, SEX, SAFFL) + chat-driven
##     filtering via LLM tool calls share a unified reactive filter state
##   * otel spans, metrics, and logs instrument every key operation
##   * Shiny modules split UI / server responsibilities:
##       - kpi_module    : value-box summaries of the filtered data
##       - table_module  : interactive {reactable} table
##       - plots_module  : {plotly} visualizations

library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(plotly)
library(reactable)
library(shinychat)
library(ellmer)
library(otel)
library(random.cdisc.data)

# ---- OpenTelemetry setup ----------------------------------------------------

# Set tracer name for this application — used as the "scope" in all otel calls
otel_tracer_name <- "shiny.adsl.explorer"

otel::log("Application starting", attributes = list(app = "adsl-explorer"))

# ---- Data -------------------------------------------------------------------

# Pick a focused set of ADSL columns so the LLM has a cleaner schema to reason
# about. Drop columns that are constant or too sparse to be useful for demo.
# Note: {random.cdisc.data}'s `cadsl` does not ship with AGEGR1, so we derive
# the standard <65 / 65-<75 / >=75 grouping ourselves.
adsl <- random.cdisc.data::cadsl |>
  mutate(
    AGEGR1 = cut(
      AGE,
      breaks = c(-Inf, 65, 75, Inf),
      right = FALSE,
      labels = c("<65", "65-<75", ">=75")
    )
  ) |>
  select(
    USUBJID,
    STUDYID,
    AGE,
    AGEU,
    AGEGR1,
    SEX,
    RACE,
    ETHNIC,
    COUNTRY,
    ARM,
    ARMCD,
    ACTARM,
    TRT01P,
    TRT01A,
    SAFFL,
    ITTFL,
    BEP01FL,
    BMEASIFL,
    EOSSTT,
    DCSREAS,
    STRATA1,
    STRATA2,
    BMRKR1,
    BMRKR2
  ) |>
  mutate(across(where(is.factor), as.character))

otel::log(
  "Data loaded",
  attributes = list(rows = nrow(adsl), cols = ncol(adsl))
)

# Pre-compute values for filter controls
all_arms <- sort(unique(adsl$ARM))
all_sexes <- sort(unique(adsl$SEX))
age_range <- as.numeric(range(adsl$AGE, na.rm = TRUE))

# ---- System prompt for chat -------------------------------------------------

data_desc <- paste(readLines("data_description.md"), collapse = "\n")
greeting <- paste(readLines("greeting.md"), collapse = "\n")

system_prompt <- paste0(
  "You are a helpful clinical data analyst assistant. You help users explore ",
  "the ADSL (Subject-Level Analysis) dataset from a simulated clinical trial.\n\n",
  "## Dataset Description\n\n",
  data_desc,
  "\n\n",
  "## Additional Instructions\n\n",
  "When the user asks for a 'summary' or 'overview', prefer grouping by ARM.\n",
  "Treatment arm labels include 'A: Drug X', 'B: Placebo', 'C: Combination'.\n",
  "Flag columns use 'Y' and 'N' as strings.\n\n",
  "You have access to tools that can filter the displayed data and run ",
  "aggregation queries. Use them when the user asks to filter, sort, or ",
  "summarize the data. When answering questions about the data, use the ",
  "query_data tool to compute the answer rather than guessing.\n\n",
  "When the user asks to reset or clear filters, use the reset_filters tool.\n\n",
  "Keep responses concise and clinically relevant."
)

# ---- KPI module -------------------------------------------------------------

kpi_ui <- function(id) {
  ns <- NS(id)
  layout_column_wrap(
    width = 1 / 4,
    fill = FALSE,
    value_box(
      title = "Subjects",
      value = textOutput(ns("n_subjects")),
      showcase = bs_icon("people-fill"),
      theme = "primary"
    ),
    value_box(
      title = "Treatment arms",
      value = textOutput(ns("n_arms")),
      showcase = bs_icon("capsule"),
      theme = "success"
    ),
    value_box(
      title = "Mean age",
      value = textOutput(ns("mean_age")),
      showcase = bs_icon("calendar-heart"),
      theme = "info"
    ),
    value_box(
      title = "Mean biomarker 1",
      value = textOutput(ns("mean_bmrkr1")),
      showcase = bs_icon("activity"),
      theme = "warning"
    )
  )
}

kpi_server <- function(id, filtered_df) {
  moduleServer(id, function(input, output, session) {
    output$n_subjects <- renderText({
      spn <- otel::start_local_active_span("kpi_render_n_subjects")
      n <- nrow(filtered_df())
      otel::counter_add("kpi.render.count", 1, list(kpi = "n_subjects"))
      format(n, big.mark = ",")
    })

    output$n_arms <- renderText({
      spn <- otel::start_local_active_span("kpi_render_n_arms")
      otel::counter_add("kpi.render.count", 1, list(kpi = "n_arms"))
      length(unique(filtered_df()$ARM))
    })

    output$mean_age <- renderText({
      spn <- otel::start_local_active_span("kpi_render_mean_age")
      otel::counter_add("kpi.render.count", 1, list(kpi = "mean_age"))
      x <- filtered_df()$AGE
      if (length(x) == 0) "\u2014" else sprintf("%.1f", mean(x, na.rm = TRUE))
    })

    output$mean_bmrkr1 <- renderText({
      spn <- otel::start_local_active_span("kpi_render_mean_bmrkr1")
      otel::counter_add("kpi.render.count", 1, list(kpi = "mean_bmrkr1"))
      x <- filtered_df()$BMRKR1
      if (length(x) == 0 || all(is.na(x))) {
        "\u2014"
      } else {
        sprintf("%.2f", mean(x, na.rm = TRUE))
      }
    })
  })
}

# ---- Table module -----------------------------------------------------------

table_ui <- function(id) {
  ns <- NS(id)
  card(
    card_header(textOutput(ns("title"))),
    reactableOutput(ns("table")),
    full_screen = TRUE
  )
}

table_server <- function(id, filtered_df, current_title) {
  moduleServer(id, function(input, output, session) {
    output$title <- renderText({
      current_title() %||% "All subjects (no filter)"
    })

    output$table <- renderReactable({
      spn <- otel::start_local_active_span(
        "render_table",
        attributes = otel::as_attributes(list(rows = nrow(filtered_df())))
      )
      otel::counter_add("table.render.count", 1)
      otel::log(
        "Rendering data table",
        attributes = list(rows = nrow(filtered_df()))
      )

      reactable(
        filtered_df(),
        searchable = TRUE,
        filterable = TRUE,
        defaultPageSize = 10,
        highlight = TRUE,
        compact = TRUE,
        striped = TRUE,
        wrap = FALSE,
        defaultColDef = colDef(minWidth = 90)
      )
    })
  })
}

# ---- Plots module -----------------------------------------------------------

plots_ui <- function(id) {
  ns <- NS(id)
  layout_columns(
    col_widths = c(6, 6, 6, 6),
    card(
      card_header("Subjects per treatment arm"),
      plotlyOutput(ns("arm_bar")),
      full_screen = TRUE
    ),
    card(
      card_header("Age distribution by arm"),
      plotlyOutput(ns("age_box")),
      full_screen = TRUE
    ),
    card(
      card_header("Biomarker 1 by age group"),
      plotlyOutput(ns("bmrkr_scatter")),
      full_screen = TRUE
    ),
    card(
      card_header("End-of-study status"),
      plotlyOutput(ns("eosstt_bar")),
      full_screen = TRUE
    )
  )
}

plots_server <- function(id, filtered_df) {
  moduleServer(id, function(input, output, session) {
    empty_plot <- function(msg = "No data for current filter") {
      plot_ly() |>
        layout(
          xaxis = list(visible = FALSE),
          yaxis = list(visible = FALSE),
          annotations = list(
            list(text = msg, showarrow = FALSE, font = list(size = 14))
          )
        )
    }

    output$arm_bar <- renderPlotly({
      spn <- otel::start_local_active_span("render_plot_arm_bar")
      otel::counter_add("plot.render.count", 1, list(plot = "arm_bar"))
      d <- filtered_df()
      if (nrow(d) == 0) {
        return(empty_plot())
      }
      d |>
        count(ARM) |>
        plot_ly(x = ~ARM, y = ~n, type = "bar", color = ~ARM) |>
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Subjects"),
          showlegend = FALSE
        )
    })

    output$age_box <- renderPlotly({
      spn <- otel::start_local_active_span("render_plot_age_box")
      otel::counter_add("plot.render.count", 1, list(plot = "age_box"))
      d <- filtered_df()
      if (nrow(d) == 0) {
        return(empty_plot())
      }
      plot_ly(d, x = ~ARM, y = ~AGE, color = ~ARM, type = "box") |>
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Age (years)"),
          showlegend = FALSE
        )
    })

    output$bmrkr_scatter <- renderPlotly({
      spn <- otel::start_local_active_span("render_plot_bmrkr_scatter")
      otel::counter_add("plot.render.count", 1, list(plot = "bmrkr_scatter"))
      d <- filtered_df()
      if (nrow(d) == 0 || all(is.na(d$BMRKR1))) {
        return(empty_plot())
      }
      plot_ly(
        d,
        x = ~AGEGR1,
        y = ~BMRKR1,
        color = ~ARM,
        text = ~ paste("USUBJID:", USUBJID, "<br>SEX:", SEX, "<br>AGE:", AGE),
        type = "box",
        boxpoints = "all",
        jitter = 0.4,
        pointpos = 0,
        marker = list(opacity = 0.6, size = 5)
      ) |>
        layout(
          boxmode = "group",
          xaxis = list(title = "Age group"),
          yaxis = list(title = "Biomarker 1 (BMRKR1)")
        )
    })

    output$eosstt_bar <- renderPlotly({
      spn <- otel::start_local_active_span("render_plot_eosstt_bar")
      otel::counter_add("plot.render.count", 1, list(plot = "eosstt_bar"))
      d <- filtered_df()
      if (nrow(d) == 0) {
        return(empty_plot())
      }
      d |>
        count(EOSSTT, ARM) |>
        plot_ly(
          x = ~EOSSTT,
          y = ~n,
          color = ~ARM,
          type = "bar"
        ) |>
        layout(
          barmode = "stack",
          xaxis = list(title = ""),
          yaxis = list(title = "Subjects")
        )
    })
  })
}

# ---- App UI -----------------------------------------------------------------

ui <- page_sidebar(
  title = "ADSL Explorer \u2014 OpenTelemetry Demo",
  class = "bslib-page-dashboard",
  sidebar = sidebar(
    width = 420,
    title = "Controls & Chat",

    # -- Manual filter controls --
    accordion(
      id = "filter_accordion",
      open = TRUE,
      accordion_panel(
        title = "Data Filters",
        icon = bs_icon("funnel"),
        checkboxGroupInput(
          "filter_arm",
          "Treatment Arm",
          choices = all_arms,
          selected = all_arms
        ),
        sliderInput(
          "filter_age",
          "Age Range",
          min = age_range[1],
          max = age_range[2],
          value = age_range,
          step = 1
        ),
        checkboxGroupInput(
          "filter_sex",
          "Sex",
          choices = all_sexes,
          selected = all_sexes
        ),
        checkboxInput(
          "filter_saffl",
          "Safety population only (SAFFL = Y)",
          value = FALSE
        ),
        actionButton(
          "reset_filters_btn",
          "Reset All Filters",
          icon = icon("rotate-left"),
          class = "btn-outline-secondary btn-sm mt-2 w-100"
        )
      )
    ),

    # -- Chat interface --
    chat_ui(
      "chat",
      height = "100%",
      placeholder = "Ask about the clinical data...",
      messages = greeting
    )
  ),

  kpi_ui("kpis"),
  plots_ui("plots"),
  table_ui("tbl")
)

# ---- App Server -------------------------------------------------------------

server <- function(input, output, session) {
  otel::log_info("Shiny session started")
  spn_session <- otel::start_local_active_span("shiny_session")

  # -- Reactive state for chat-driven filters --
  # These hold filter criteria set by the LLM via tool calls
  chat_filter_expr <- reactiveVal(NULL) # A quosure or NULL
  chat_filter_title <- reactiveVal(NULL) # Short description string

  # -- Create ellmer chat client (per session) --
  chat <- ellmer::chat_anthropic(
    system_prompt = system_prompt,
    model = "claude-sonnet-4-5-20250929"
  )

  # ---- Define LLM tools ----------------------------------------------------

  # Tool: filter the displayed data using dplyr-style expressions
  tool_filter_data <- ellmer::tool(
    function(filter_expr, title) {
      spn <- otel::start_local_active_span(
        "tool_filter_data",
        attributes = otel::as_attributes(list(
          filter_expr = filter_expr,
          title = title
        ))
      )
      otel::log(
        "Chat filter applied",
        attributes = list(
          filter_expr = filter_expr,
          title = title
        )
      )
      otel::counter_add("chat.tool.call.count", 1, list(tool = "filter_data"))

      # Evaluate the filter expression against the full dataset
      tryCatch(
        {
          expr <- rlang::parse_expr(filter_expr)
          result <- dplyr::filter(adsl, !!expr)
          n <- nrow(result)

          # Store the parsed expression and title for the reactive pipeline
          chat_filter_expr(expr)
          chat_filter_title(title)

          otel::histogram_record("chat.filter.result.rows", n)
          paste0(
            "Filter applied: '",
            title,
            "'. ",
            n,
            " of ",
            nrow(adsl),
            " subjects match."
          )
        },
        error = function(e) {
          paste0(
            "Error applying filter: ",
            conditionMessage(e),
            ". Please try a different expression."
          )
        }
      )
    },
    name = "filter_data",
    description = paste(
      "Filter the ADSL data table displayed in the dashboard.",
      "The filter_expr must be a valid R expression that can be passed to",
      "dplyr::filter(). Use column names from the dataset description.",
      "Examples: 'ARM == \"A: Drug X\"', 'AGE > 65 & SAFFL == \"Y\"',",
      "'EOSSTT == \"COMPLETED\" & SEX == \"F\"'.",
      "The title should be a short human-readable description of the filter."
    ),
    arguments = list(
      filter_expr = ellmer::type_string(
        "A valid R/dplyr filter expression (e.g., 'AGE > 65 & ARM == \"A: Drug X\"')"
      ),
      title = ellmer::type_string(
        "Short human-readable title for the filter (e.g., 'Drug X patients over 65')"
      )
    ),
    annotations = ellmer::tool_annotations(
      title = "Filter Data",
      read_only_hint = FALSE
    )
  )

  # Tool: run a summary/aggregation query and return results inline
  tool_query_data <- ellmer::tool(
    function(query_code) {
      spn <- otel::start_local_active_span(
        "tool_query_data",
        attributes = otel::as_attributes(list(
          query_code = query_code
        ))
      )
      otel::log(
        "Chat query executed",
        attributes = list(query_code = query_code)
      )
      otel::counter_add("chat.tool.call.count", 1, list(tool = "query_data"))

      tryCatch(
        {
          # Build a safe expression: start from adsl, pipe through the query
          expr <- rlang::parse_expr(paste0("adsl |> ", query_code))
          result <- eval(expr)

          if (is.data.frame(result)) {
            # Format as a readable text table
            otel::histogram_record("chat.query.result.rows", nrow(result))
            paste0(
              "Query result (",
              nrow(result),
              " rows):\n\n",
              paste(
                utils::capture.output(print(result, n = 50)),
                collapse = "\n"
              )
            )
          } else {
            paste0("Result: ", paste(result, collapse = ", "))
          }
        },
        error = function(e) {
          paste0(
            "Error executing query: ",
            conditionMessage(e),
            ". Please try a different expression."
          )
        }
      )
    },
    name = "query_data",
    description = paste(
      "Run a dplyr query/aggregation on the ADSL dataset and return the result",
      "inline in the chat. The query_code should be dplyr pipeline code that",
      "will be appended to 'adsl |> ...'. Examples:",
      "'group_by(ARM) |> summarise(mean_age = mean(AGE, na.rm = TRUE))',",
      "'count(SEX, ARM)',",
      "'filter(SAFFL == \"Y\") |> summarise(n = n(), mean_bmrkr1 = mean(BMRKR1, na.rm = TRUE))'.",
      "Use this tool for questions that need computed answers (counts, means, etc.)."
    ),
    arguments = list(
      query_code = ellmer::type_string(
        paste(
          "dplyr pipeline code to append to 'adsl |> ...'.",
          "Example: 'group_by(ARM) |> summarise(n = n())'"
        )
      )
    ),
    annotations = ellmer::tool_annotations(
      title = "Query Data",
      read_only_hint = TRUE
    )
  )

  # Tool: reset all chat-driven filters
  tool_reset <- ellmer::tool(
    function() {
      spn <- otel::start_local_active_span("tool_reset_filters")
      otel::log_info("Chat-driven filters reset via tool")
      otel::counter_add("chat.tool.call.count", 1, list(tool = "reset_filters"))

      chat_filter_expr(NULL)
      chat_filter_title(NULL)
      "All chat-driven filters have been cleared. The dashboard now shows data based on the manual filter controls only."
    },
    name = "reset_filters",
    description = "Reset/clear all chat-driven data filters. Use when the user asks to reset, clear, or remove filters.",
    arguments = list(),
    annotations = ellmer::tool_annotations(
      title = "Reset Filters",
      read_only_hint = FALSE
    )
  )

  # Register all tools
  chat$register_tool(tool_filter_data)
  chat$register_tool(tool_query_data)
  chat$register_tool(tool_reset)

  # ---- Chat interaction handler ---------------------------------------------

  observeEvent(input$chat_user_input, {
    user_msg <- input$chat_user_input

    spn <- otel::start_local_active_span(
      "chat_user_message",
      attributes = otel::as_attributes(list(
        message_length = nchar(user_msg)
      ))
    )
    otel::log(
      "User chat message received",
      attributes = list(length = nchar(user_msg))
    )
    otel::counter_add("chat.message.count", 1, list(role = "user"))

    # Stream the response with tool-call content rendering
    stream <- chat$stream_async(user_msg, stream = "content")
    chat_append("chat", stream)

    otel::counter_add("chat.message.count", 1, list(role = "assistant"))
  })

  # ---- Manual filter: Reset button ------------------------------------------

  observeEvent(input$reset_filters_btn, {
    spn <- otel::start_local_active_span("manual_reset_filters")
    otel::log_info("Manual filter reset triggered")
    otel::counter_add("filter.reset.count", 1)

    updateCheckboxGroupInput(session, "filter_arm", selected = all_arms)
    updateSliderInput(session, "filter_age", value = age_range)
    updateCheckboxGroupInput(session, "filter_sex", selected = all_sexes)
    updateCheckboxInput(session, "filter_saffl", value = FALSE)

    # Also clear chat-driven filters
    chat_filter_expr(NULL)
    chat_filter_title(NULL)
  })

  # ---- Unified filtered data reactive ---------------------------------------

  filtered_df <- reactive({
    spn <- otel::start_local_active_span("compute_filtered_df")

    d <- adsl

    # Apply manual filters
    selected_arms <- input$filter_arm
    selected_sex <- input$filter_sex
    age_bounds <- input$filter_age
    saffl_only <- input$filter_saffl

    if (!is.null(selected_arms) && length(selected_arms) > 0) {
      d <- d |> filter(ARM %in% selected_arms)
    }
    if (!is.null(age_bounds)) {
      d <- d |> filter(AGE >= age_bounds[1], AGE <= age_bounds[2])
    }
    if (!is.null(selected_sex) && length(selected_sex) > 0) {
      d <- d |> filter(SEX %in% selected_sex)
    }
    if (isTRUE(saffl_only)) {
      d <- d |> filter(SAFFL == "Y")
    }

    # Apply chat-driven filter (if any)
    chat_expr <- chat_filter_expr()
    if (!is.null(chat_expr)) {
      tryCatch(
        {
          d <- d |> filter(!!chat_expr)
        },
        error = function(e) {
          otel::log_warn(
            "Chat filter expression failed during reactive eval",
            error = conditionMessage(e)
          )
        }
      )
    }

    # Record metrics about the result
    n_rows <- nrow(d)
    otel::gauge_record("filter.result.row_count", n_rows)
    otel::histogram_record("filter.result.rows", n_rows)

    # Count active manual filters
    n_active_filters <- sum(
      !setequal(selected_arms %||% all_arms, all_arms),
      !identical(age_bounds, age_range),
      !setequal(selected_sex %||% all_sexes, all_sexes),
      isTRUE(saffl_only),
      !is.null(chat_expr)
    )
    otel::gauge_record("filter.active.count", n_active_filters)

    otel::log(
      "Filtered data computed",
      attributes = list(rows = n_rows, active_filters = n_active_filters)
    )

    d
  })

  # ---- Build display title from active filters ------------------------------

  current_title <- reactive({
    parts <- character(0)

    # Manual filter descriptions
    if (!setequal(input$filter_arm %||% all_arms, all_arms)) {
      parts <- c(parts, paste("ARM:", paste(input$filter_arm, collapse = ", ")))
    }
    if (!identical(input$filter_age, age_range)) {
      parts <- c(
        parts,
        sprintf("Age %d\u2013%d", input$filter_age[1], input$filter_age[2])
      )
    }
    if (!setequal(input$filter_sex %||% all_sexes, all_sexes)) {
      parts <- c(parts, paste("Sex:", paste(input$filter_sex, collapse = ", ")))
    }
    if (isTRUE(input$filter_saffl)) {
      parts <- c(parts, "Safety pop.")
    }

    # Chat-driven filter title
    ct <- chat_filter_title()
    if (!is.null(ct)) {
      parts <- c(parts, ct)
    }

    if (length(parts) == 0) NULL else paste(parts, collapse = " | ")
  })

  # ---- Wire up modules ------------------------------------------------------

  kpi_server("kpis", filtered_df)
  plots_server("plots", filtered_df)
  table_server("tbl", filtered_df, current_title)

  # ---- Session cleanup ------------------------------------------------------

  session$onSessionEnded(function() {
    otel::log_info("Shiny session ended")
  })
}

shinyApp(ui, server)
