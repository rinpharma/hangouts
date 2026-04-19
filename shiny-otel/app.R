## querychat + random.cdisc.data demo -----------------------------------------
##
## A Shiny application demonstrating the {querychat} package against the
## ADSL (Subject-Level Analysis Dataset) from {random.cdisc.data}.
##
## Architecture:
##   * Shiny modules split UI / server responsibilities:
##       - kpi_module    : value-box summaries of the filtered data
##       - table_module  : interactive {reactable} table
##       - plots_module  : {plotly} visualizations
##   * A single QueryChat instance provides the chat sidebar and exposes
##     reactive values (df, sql, title) consumed by every module.

library(shiny)
library(bslib)
library(bsicons)
library(dplyr)
library(plotly)
library(reactable)
library(querychat)
library(random.cdisc.data)

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
    USUBJID, STUDYID, AGE, AGEU, AGEGR1, SEX, RACE, ETHNIC, COUNTRY,
    ARM, ARMCD, ACTARM, TRT01P, TRT01A,
    SAFFL, ITTFL, BEP01FL, BMEASIFL,
    EOSSTT, DCSREAS,
    STRATA1, STRATA2,
    BMRKR1, BMRKR2
  ) |>
  # querychat / SQL back-ends get along better with plain strings than factors
  mutate(across(where(is.factor), as.character))

# ---- QueryChat instance -----------------------------------------------------

qc <- QueryChat$new(
  adsl,
  table_name = "adsl",
  greeting = "greeting.md",
  data_description = "data_description.md",
  client = "anthropic/claude-sonnet-4-5",
  extra_instructions = paste(
    "When the user asks for a 'summary' or 'overview', prefer grouping by ARM.",
    "Treatment arm labels include 'A: Drug X', 'B: Placebo', 'C: Combination'.",
    "Flag columns use 'Y' and 'N' as strings."
  )
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
      format(nrow(filtered_df()), big.mark = ",")
    })
    output$n_arms <- renderText({
      length(unique(filtered_df()$ARM))
    })
    output$mean_age <- renderText({
      x <- filtered_df()$AGE
      if (length(x) == 0) "—" else sprintf("%.1f", mean(x, na.rm = TRUE))
    })
    output$mean_bmrkr1 <- renderText({
      x <- filtered_df()$BMRKR1
      if (length(x) == 0 || all(is.na(x))) "—" else sprintf("%.2f", mean(x, na.rm = TRUE))
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
      d <- filtered_df()
      if (nrow(d) == 0) return(empty_plot())
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
      d <- filtered_df()
      if (nrow(d) == 0) return(empty_plot())
      plot_ly(d, x = ~ARM, y = ~AGE, color = ~ARM, type = "box") |>
        layout(
          xaxis = list(title = ""),
          yaxis = list(title = "Age (years)"),
          showlegend = FALSE
        )
    })

    output$bmrkr_scatter <- renderPlotly({
      d <- filtered_df()
      if (nrow(d) == 0 || all(is.na(d$BMRKR1))) return(empty_plot())
      plot_ly(
        d,
        x = ~AGEGR1,
        y = ~BMRKR1,
        color = ~ARM,
        text = ~paste("USUBJID:", USUBJID, "<br>SEX:", SEX, "<br>AGE:", AGE),
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
      d <- filtered_df()
      if (nrow(d) == 0) return(empty_plot())
      d |>
        count(EOSSTT, ARM) |>
        plot_ly(
          x = ~EOSSTT, y = ~n, color = ~ARM, type = "bar"
        ) |>
        layout(
          barmode = "stack",
          xaxis = list(title = ""),
          yaxis = list(title = "Subjects")
        )
    })
  })
}

# ---- App --------------------------------------------------------------------

ui <- page_sidebar(
  title = "ADSL explorer — querychat demo",
  class = "bslib-page-dashboard",
  sidebar = qc$sidebar(width = 420),
  kpi_ui("kpis"),
  plots_ui("plots"),
  table_ui("tbl")
)

server <- function(input, output, session) {
  qc_vals <- qc$server()

  filtered_df <- reactive({
    qc_vals$df()
  })

  kpi_server("kpis", filtered_df)
  plots_server("plots", filtered_df)
  table_server("tbl", filtered_df, qc_vals$title)
}

shinyApp(ui, server)
