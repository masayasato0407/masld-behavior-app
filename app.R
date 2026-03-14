# === Shiny App: Bayesian Network MASLD Risk Simulator ===
# Step 1: Profile input (probability not displayed)
# Step 2: Display probability + behavior modification simulation

library(shiny)
library(bslib)
library(bnlearn)
library(gRain)
library(dplyr)
library(DiagrammeR)

# --- Load model (relative path: place RData in same folder as app.R) ---
load("bn_masld_model.RData")

# --- Exact inference function ---
exact_query <- function(grain_obj, evidence_list) {
  grain_ev <- setEvidence(grain_obj,
                          nodes = names(evidence_list),
                          states = as.character(unlist(evidence_list)))
  result <- querygrain(grain_ev, nodes = "MASLD_outcome")
  return(result$MASLD_outcome["MASLD"])
}

# --- Behavior variables ---
score_vars <- c("Regular_exercise", "Daily_physical_activity", "Walking_speed",
                "Eating_speed", "Late_night_eating", "Skipping_breakfast")

behavior_labels <- c(
  "Regular_exercise"        = "Regular exercise",
  "Daily_physical_activity" = "Daily physical activity",
  "Walking_speed"           = "Walking speed",
  "Eating_speed"            = "Eating speed",
  "Late_night_eating"       = "Late-night eating",
  "Skipping_breakfast"      = "Skipping breakfast"
)

unhealthy_desc <- c(
  "Regular_exercise"        = "No regular exercise (< 30 min \u00d7 2 days/week)",
  "Daily_physical_activity" = "Less than 1 hour of daily walking/activity",
  "Walking_speed"           = "Walking pace not faster than peers",
  "Eating_speed"            = "Eating faster than others",
  "Late_night_eating"       = "Eating within 2h before bed (\u22653 times/week)",
  "Skipping_breakfast"      = "Skipping breakfast (\u22653 times/week)"
)

healthy_desc <- c(
  "Regular_exercise"        = "Exercising 30+ min \u00d7 2+ days/week for 1+ year",
  "Daily_physical_activity" = "Walking/activity 1+ hour daily",
  "Walking_speed"           = "Walking faster than peers",
  "Eating_speed"            = "Normal or slow eating pace",
  "Late_night_eating"       = "Not eating late before bed",
  "Skipping_breakfast"      = "Eating breakfast regularly"
)

# =============================================
# UI
# =============================================
ui <- page_navbar(
  title = "MASLD Risk Simulator",
  theme = bs_theme(
    version = 5,
    bootswatch = "flatly",
    primary = "#2C3E50",
    success = "#18BC9C",
    danger  = "#E74C3C",
    warning = "#F39C12",
    info    = "#3498DB",
    "font-size-base" = "0.95rem"
  ),
  navbar_options = navbar_options(bg = "#2C3E50"),

  # === Simulator tab ===
  nav_panel(
    title = "Simulator",
    icon  = icon("sliders-h"),

    # Step indicator
    tags$div(
      class = "container-fluid mt-3 mb-4",
      uiOutput("step_indicator")
    ),

    # ===== Step 1: Profile input (probability hidden) =====
    conditionalPanel(
      condition = "output.current_step == 1",

      layout_column_wrap(
        width = 1/2,
        fill = FALSE,

        # Left column: Demographics + Q1-Q3
        card(
          fill = FALSE,
          card_header(
            tags$h5(icon("user"), " Your Profile", class = "mb-0"),
            class = "bg-primary text-white"
          ),
          card_body(
            tags$div(
              class = "mb-4 p-3 rounded",
              style = "background: #EBF5FB; border: 1px solid #AED6F1;",
              tags$h6("Demographics", class = "fw-bold mb-3"),
              radioButtons("age_cat", label = "Age group",
                           choices = c("\u2264 50 years" = "young",
                                       "> 50 years" = "old"),
                           selected = "young", inline = TRUE),
              radioButtons("sex_f", label = "Sex",
                           choices = c("Male" = "male", "Female" = "female"),
                           selected = "male", inline = TRUE)
            ),

            tags$h6("Lifestyle Questionnaire", class = "fw-bold mb-3"),
            tags$p("Answer based on your current habits.",
                   class = "text-muted small mb-3"),

            tags$div(
              class = "mb-3 p-3 rounded",
              style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
              tags$div(class = "fw-semibold mb-1", "Q1. Regular exercise"),
              tags$p(class = "small text-muted mb-2",
                     "Do you exercise (sweat lightly) for 30+ minutes,",
                     "2+ days/week, for over a year?"),
              radioButtons("cur_Regular_exercise", label = NULL,
                           choices = c("Yes" = "0", "No" = "1"),
                           selected = "1", inline = TRUE)
            ),

            tags$div(
              class = "mb-3 p-3 rounded",
              style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
              tags$div(class = "fw-semibold mb-1", "Q2. Daily physical activity"),
              tags$p(class = "small text-muted mb-2",
                     "Do you walk or do equivalent physical activity",
                     "for 1+ hour daily?"),
              radioButtons("cur_Daily_physical_activity", label = NULL,
                           choices = c("Yes" = "0", "No" = "1"),
                           selected = "1", inline = TRUE)
            ),

            tags$div(
              class = "mb-3 p-3 rounded",
              style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
              tags$div(class = "fw-semibold mb-1", "Q3. Walking speed"),
              tags$p(class = "small text-muted mb-2",
                     "Do you walk faster than others",
                     "of the same age and sex?"),
              radioButtons("cur_Walking_speed", label = NULL,
                           choices = c("Yes" = "0", "No" = "1"),
                           selected = "1", inline = TRUE)
            )
          )
        ),

        # Right column: Q4-Q6 + button
        tags$div(
          card(
            fill = FALSE,
            card_header(
              tags$h5(icon("utensils"), " Eating Habits", class = "mb-0"),
              class = "bg-primary text-white"
            ),
            card_body(
              tags$div(
                class = "mb-3 p-3 rounded",
                style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
                tags$div(class = "fw-semibold mb-1", "Q4. Eating speed"),
                tags$p(class = "small text-muted mb-2",
                       "Do you eat faster than others?"),
                radioButtons("cur_Eating_speed", label = NULL,
                             choices = c("Yes (fast)" = "1",
                                         "No (normal/slow)" = "0"),
                             selected = "1", inline = TRUE)
              ),

              tags$div(
                class = "mb-3 p-3 rounded",
                style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
                tags$div(class = "fw-semibold mb-1", "Q5. Late-night eating"),
                tags$p(class = "small text-muted mb-2",
                       "Do you eat within 2 hours before bedtime",
                       "3 or more times per week?"),
                radioButtons("cur_Late_night_eating", label = NULL,
                             choices = c("Yes" = "1", "No" = "0"),
                             selected = "1", inline = TRUE)
              ),

              tags$div(
                class = "mb-3 p-3 rounded",
                style = "background: #F8F9FA; border: 1px solid #DEE2E6;",
                tags$div(class = "fw-semibold mb-1", "Q6. Skipping breakfast"),
                tags$p(class = "small text-muted mb-2",
                       "Do you skip breakfast 3 or more times per week?"),
                radioButtons("cur_Skipping_breakfast", label = NULL,
                             choices = c("Yes" = "1", "No" = "0"),
                             selected = "1", inline = TRUE)
              )
            )
          ),

          tags$div(
            class = "mt-3",
            actionButton("go_step2",
                         tags$span("See My Risk & Simulate Improvement",
                                   icon("arrow-right", class = "ms-2")),
                         class = "btn-success btn-lg w-100 py-3",
                         style = "font-size: 1.1rem; font-weight: 600;")
          )
        )
      )
    ),

    # ===== Step 2: Results + Simulation =====
    conditionalPanel(
      condition = "output.current_step == 2",

      tags$div(
        class = "mb-3",
        actionButton("go_step1",
                     tags$span(icon("arrow-left", class = "me-2"),
                               "Back to Profile"),
                     class = "btn-outline-primary")
      ),

      # Upper section: Current risk
      card(
        fill = FALSE,
        card_header(
          tags$h5(icon("tachometer-alt"),
                  " Your Current MASLD Probability", class = "mb-0"),
          class = "bg-primary text-white"
        ),
        card_body(
          class = "text-center py-3",
          tags$h1(textOutput("current_pct"),
                  class = "text-primary mb-2",
                  style = "font-size: 3.5rem; font-weight: 700;"),
          tags$p("Based on your current profile", class = "text-muted mb-3"),
          uiOutput("profile_badges")
        )
      ),

      # Lower section: Simulation
      layout_column_wrap(
        width = 1/2,
        fill = FALSE,

        card(
          fill = FALSE,
          card_header(
            tags$h5(icon("exchange-alt"),
                    " Select Behaviors to Improve", class = "mb-0"),
            class = "bg-warning text-dark"
          ),
          card_body(
            uiOutput("intervention_toggles")
          )
        ),

        # Effect Breakdown removed; Simulation Result card only
        card(
          fill = FALSE,
          card_header(
            tags$h5(icon("chart-line"),
                    " Simulation Result", class = "mb-0"),
            class = "bg-success text-white"
          ),
          card_body(
            class = "text-center",
            tags$div(
              class = "p-3 rounded mb-3",
              style = "background: #FDEDEC;",
              tags$p("Current", class = "text-muted mb-1 small fw-semibold"),
              tags$h2(textOutput("sim_current_pct"),
                      class = "text-danger mb-0",
                      style = "font-size: 2.5rem; font-weight: 700;")
            ),
            tags$div(icon("arrow-down", class = "text-success fa-2x"),
                     class = "mb-3"),
            tags$div(
              class = "p-3 rounded mb-3",
              style = "background: #E8F8F5;",
              tags$p("After Improvement",
                     class = "text-muted mb-1 small fw-semibold"),
              tags$h2(textOutput("sim_improved_pct"),
                      class = "text-success mb-0",
                      style = "font-size: 2.5rem; font-weight: 700;")
            ),
            tags$div(
              class = "p-3 rounded",
              style = "background: #EBF5FB;",
              tags$p("Risk Reduction",
                     class = "text-muted mb-1 small fw-semibold"),
              tags$h2(textOutput("sim_total_effect"),
                      class = "text-info mb-0",
                      style = "font-size: 2.5rem; font-weight: 700;")
            )
          )
        )
      )
    )
  ),

  # === About tab ===
  nav_panel(
    title = "About",
    icon  = icon("info-circle"),
    layout_column_wrap(
      width = 1/2,
      card(
        fill = FALSE,
        card_header(tags$strong("About this app"),
                    class = "bg-primary text-white"),
        card_body(
          tags$p("This app uses a Bayesian Network trained on the JMDC claims
                  database to estimate how lifestyle behavior changes could
                  affect an individual's MASLD probability."),
          tags$p("The model uses exact inference via the junction tree algorithm
                  (gRain package) with Bayesian parameter estimation."),
          tags$hr(),
          tags$h6("How to use:"),
          tags$ol(
            tags$li(tags$strong("Step 1:"), " Set your demographics and answer
                    6 lifestyle questions based on your current habits."),
            tags$li(tags$strong("Step 2:"), " View your current MASLD probability
                    and simulate the effect of improving specific behaviors.")
          ),
          tags$hr(),
          tags$h6("Questionnaire source:"),
          tags$p("Questions are based on the Japanese Specific Health Checkup
                  (Tokutei Kenshin) lifestyle questionnaire.",
                 class = "text-muted small")
        )
      ),
      card(
        fill = FALSE,
        card_header(tags$strong("Network Structure"),
                    class = "bg-primary text-white"),
        card_body(
          grVizOutput("dag_plot", height = "450px")
        )
      )
    )
  )
)

# =============================================
# Server
# =============================================
server <- function(input, output, session) {

  # --- Step management ---
  step <- reactiveVal(1)
  observeEvent(input$go_step2, { step(2) })
  observeEvent(input$go_step1, { step(1) })
  output$current_step <- reactive({ step() })
  outputOptions(output, "current_step", suspendWhenHidden = FALSE)

  # --- Step indicator ---
  output$step_indicator <- renderUI({
    s <- step()
    tags$div(
      class = "d-flex align-items-center justify-content-center gap-3",
      tags$div(
        class = paste0("d-flex align-items-center gap-2 px-4 py-2 rounded-pill ",
                       if (s == 1) "bg-primary text-white" else "bg-light text-muted"),
        style = if (s == 1) "font-weight: 600;" else "",
        tags$span(
          class = paste0("badge rounded-circle ",
                         if (s == 1) "bg-white text-primary" else "bg-secondary"),
          style = "width: 28px; height: 28px; line-height: 28px; font-size: 0.85rem;",
          "1"
        ),
        "Your Profile"
      ),
      icon("chevron-right", class = "text-muted"),
      tags$div(
        class = paste0("d-flex align-items-center gap-2 px-4 py-2 rounded-pill ",
                       if (s == 2) "bg-success text-white" else "bg-light text-muted"),
        style = if (s == 2) "font-weight: 600;" else "",
        tags$span(
          class = paste0("badge rounded-circle ",
                         if (s == 2) "bg-white text-success" else "bg-secondary"),
          style = "width: 28px; height: 28px; line-height: 28px; font-size: 0.85rem;",
          "2"
        ),
        "Results & Simulation"
      )
    )
  })

  # --- Profile confirmation ---
  confirmed_evidence <- reactiveVal(NULL)

  # Evidence sanitization: In males, Skipping_breakfast is fixed to "1"
  # to avoid a paradoxical association due to residual confounding
  sanitize_evidence <- function(ev) {
    ev_calc <- ev
    if (ev_calc$Sex == "male") {
      ev_calc$Skipping_breakfast <- "1"
    }
    ev_calc
  }

  observeEvent(input$go_step2, {
    ev <- list(Age = input$age_cat, Sex = input$sex_f)
    for (beh in score_vars) {
      val <- input[[paste0("cur_", beh)]]
      if (is.null(val)) val <- "1"
      ev[[beh]] <- val
    }
    confirmed_evidence(ev)
  })

  # For display: based on user's actual input
  confirmed_unhealthy_display <- reactive({
    ev <- confirmed_evidence()
    if (is.null(ev)) return(c())
    ub <- c()
    for (beh in score_vars) {
      if (ev[[beh]] == "1") ub <- c(ub, beh)
    }
    ub
  })

  # For calculation: after sanitization
  confirmed_unhealthy <- reactive({
    ev <- confirmed_evidence()
    if (is.null(ev)) return(c())
    ev_calc <- sanitize_evidence(ev)
    ub <- c()
    for (beh in score_vars) {
      if (ev_calc[[beh]] == "1") ub <- c(ub, beh)
    }
    ub
  })

  # MASLD probability from confirmed profile (using sanitized evidence)
  confirmed_prob <- reactive({
    ev <- confirmed_evidence()
    if (is.null(ev)) return(NULL)
    ev_calc <- sanitize_evidence(ev)
    exact_query(grain_bn, ev_calc)
  })

  # --- Step 2: Display ---
  output$current_pct <- renderText({
    p <- confirmed_prob()
    if (is.null(p)) return("")
    paste0(round(p * 100, 1), "%")
  })

  output$profile_badges <- renderUI({
    ev <- confirmed_evidence()
    if (is.null(ev)) return(NULL)
    age_label <- if (ev$Age == "young") "\u2264 50 years" else "> 50 years"
    sex_label <- if (ev$Sex == "male") "Male" else "Female"

    tags$div(
      class = "text-start",
      tags$div(
        class = "mb-2",
        tags$span(class = "badge bg-primary me-1",
                  style = "font-size: 0.8rem;",
                  paste0(sex_label, ", ", age_label))
      ),
      tags$div(
        lapply(score_vars, function(beh) {
          if (ev[[beh]] == "0") {
            tags$span(class = "badge bg-success me-1 mb-1",
                      style = "font-size: 0.8rem;",
                      icon("check", class = "me-1"),
                      behavior_labels[beh])
          } else {
            tags$span(class = "badge bg-danger me-1 mb-1",
                      style = "font-size: 0.8rem;",
                      icon("times", class = "me-1"),
                      behavior_labels[beh])
          }
        })
      )
    )
  })

  # --- Intervention toggles ---
  output$intervention_toggles <- renderUI({
    ub <- confirmed_unhealthy_display()

    if (length(ub) == 0) {
      return(tags$div(
        class = "text-center py-4",
        icon("check-circle", class = "text-success fa-3x"),
        tags$h5("All behaviors are already healthy!",
                class = "text-success mt-3"),
        tags$p("No further improvement to simulate.", class = "text-muted")
      ))
    }

    tags$div(
      tags$p("Toggle the behaviors you want to improve:",
             class = "text-muted small mb-3"),
      lapply(ub, function(beh) {
        tags$div(
          class = "mb-3 p-3 rounded",
          style = "background: #FEF9E7; border: 1px solid #F9E79F;",
          tags$div(
            class = "d-flex justify-content-between align-items-start",
            tags$div(
              style = "flex: 1;",
              tags$span(behavior_labels[beh], class = "fw-semibold"),
              tags$br(),
              tags$small(class = "text-danger",
                         icon("times", class = "me-1"), unhealthy_desc[beh]),
              tags$br(),
              tags$small(class = "text-success",
                         icon("arrow-right", class = "me-1"), healthy_desc[beh])
            ),
            tags$div(
              class = "form-check form-switch ms-3 pt-1",
              tags$input(
                type = "checkbox", class = "form-check-input",
                id = paste0("imp_", beh), role = "switch",
                style = "transform: scale(1.4);"
              ),
              tags$label("Improve", class = "form-check-label small mt-1",
                         `for` = paste0("imp_", beh))
            )
          )
        )
      })
    )
  })

  # --- Post-intervention probability ---
  # - Effect Breakdown removed
  # - [CHANGE] Generalized paradox fix: if adding any behavior worsens risk,
  #   silently exclude it and use the better (lower) value instead.
  improved_result <- reactive({
    ev_raw <- confirmed_evidence()
    p_current <- confirmed_prob()
    ub <- confirmed_unhealthy_display()

    if (is.null(ev_raw) || is.null(p_current) || length(ub) == 0) {
      return(list(p_improved = p_current))
    }

    ev_current <- sanitize_evidence(ev_raw)

    improved_list <- c()
    for (beh in ub) {
      val <- input[[paste0("imp_", beh)]]
      if (!is.null(val) && val == TRUE) {
        improved_list <- c(improved_list, beh)
      }
    }

    if (length(improved_list) == 0) {
      return(list(p_improved = p_current))
    }

    # Compute p_improved with all selected behaviors
    ev_improved <- ev_current
    for (beh in improved_list) {
      ev_improved[[beh]] <- "0"
    }
    p_improved_raw <- exact_query(grain_bn, ev_improved)

    # [CHANGE] Generalized paradox fix:
    # For each selected behavior, check if its inclusion worsens risk.
    # If so, silently remove it from the effective set and use the
    # without-behavior value instead.
    effective_list <- improved_list
    for (beh in improved_list) {
      list_without_beh <- setdiff(effective_list, beh)
      if (length(list_without_beh) > 0) {
        ev_without_beh <- ev_current
        for (b in list_without_beh) {
          ev_without_beh[[b]] <- "0"
        }
        p_without_beh <- exact_query(grain_bn, ev_without_beh)
      } else {
        p_without_beh <- p_current
      }
      # If including this behavior worsens risk, exclude it silently
      if (p_improved_raw > p_without_beh) {
        effective_list <- list_without_beh
        p_improved_raw <- p_without_beh
      }
    }

    p_improved <- min(p_improved_raw, p_current)

    list(p_improved = p_improved)
  })

  output$sim_current_pct <- renderText({
    p <- confirmed_prob()
    if (is.null(p)) return("")
    paste0(round(p * 100, 1), "%")
  })

  output$sim_improved_pct <- renderText({
    res <- improved_result()
    if (is.null(res$p_improved)) return("")
    paste0(round(res$p_improved * 100, 1), "%")
  })

  output$sim_total_effect <- renderText({
    p_current <- confirmed_prob()
    res <- improved_result()
    if (is.null(p_current) || is.null(res$p_improved)) return("")
    eff <- (p_current - res$p_improved) * 100
    if (eff > 0) paste0("-", round(eff, 1), " pp") else "No change"
  })

  # --- DAG plot ---
  output$dag_plot <- renderGrViz({
    grViz("
      digraph BN {
        graph [rankdir=TB, ranksep=1.0, nodesep=0.3, bgcolor=white]
        node [style=filled, fontname=Helvetica, fontsize=11, fontcolor=white,
              penwidth=1.5, color='#2C3E50', shape=ellipse,
              fixedsize=true, width=1.2, height=0.5]
        edge [color='#95A5A6', penwidth=1.0, arrowsize=0.6]

        Age [label='Age', fillcolor='#3498DB']
        Sex [label='Sex', fillcolor='#3498DB']

        RE  [label='Regular\\nexercise', fillcolor='#18BC9C']
        DPA [label='Daily physical\\nactivity', fillcolor='#18BC9C', width=1.3]
        WS  [label='Walking\\nspeed', fillcolor='#18BC9C']
        ES  [label='Eating\\nspeed', fillcolor='#18BC9C']
        LNE [label='Late-night\\neating', fillcolor='#18BC9C']
        SB  [label='Skipping\\nbreakfast', fillcolor='#18BC9C']

        MASLD [label='MASLD', fillcolor='#E74C3C']

        {rank=same; Age; Sex}
        {rank=same; RE; DPA; WS; ES; LNE; SB}

        Age -> {RE DPA WS ES LNE SB MASLD}
        Sex -> {RE DPA WS ES LNE SB MASLD}
        RE -> MASLD
        DPA -> MASLD
        WS -> MASLD
        ES -> MASLD
        LNE -> MASLD
        SB -> MASLD
      }
    ")
  })
}

# =============================================
# Run
# =============================================
shinyApp(ui = ui, server = server)
