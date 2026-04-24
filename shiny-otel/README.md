# Using OpenTelemetry with Shiny applications

🎥 [Recording](https://rinpharma.com/docs/hangout/recordings/shiny_otel/) now available!

Within life sciences, Shiny applications are a vital component to empower data science through exploratory insights, automation pipelines, clinical design, and much more. Understanding application peformance and usage patterns when deployed to production platforms can be a challenge when trying to implement custom solutions. In this edition of the [R/Pharma](https://rinpharma.com) Hangout sessions, Posit software engineer Barret Schloerke joins us to demonstrate the power of OpenTelemetry for collecting observability data inside a Shiny application and the key benefits that aid developers in production.

## Goals of the Session

* Provide an quick introduction to OpenTelemetry
* Demonstrations of reviewing observability data inside Shiny applications using services such as Logfire

## Resources

* OpenTelmetry with Shiny article <https://shiny.posit.co/r/articles/improve/opentelemetry/>
* `{otelsdk}` vignette on collecting telemetry data <https://otelsdk.r-lib.org/reference/collecting.html>
* Logfire <https://logfire-us.pydantic.dev>
* Otel Desktop Viewer <https://github.com/CtrlSpice/otel-desktop-viewer>

## Example Application

The Shiny application contained in this repository offers a small chat interface powered by the [`{shinychat}`](https://posit-dev.github.io/shinychat/) and [`{ellmer}`](https://ellmer.tidyverse.org/) packages to explore a mock clinical data set from the [`{random.cdisc.data}`](https://insightsengineering.github.io/random.cdisc.data/main/) package.


### Development Setup

The package environment was configured using the [Nix](https://nixos.org/) package manager and the [`{rix}`](https://docs.ropensci.org/rix/) R package. If you do not have the Nix package manager available, you can simply install the packages listed in `app.R`.

### External Services

This application leverages external APIs to power the chat interface and the collection of OpenTelemetry observability data. Copy the `.Renviron.example` file and save it as `.Renviron` in your clone of the repository. Note that you should **never commit `.Renviron` to version control**! Substitute the placeholder values for key variables with your values corresponding to the following services:

* The chat interface inside the application uses the Claude Sonnet 4.5 model from Anthropic. If you wish to use the same model, you will need to create an Anthropic account with your own API key.
* The application contains two separate configurations for collecting OpenTelemetry data. Choose the one you prefer and make sure to comment out the variables associated with the other configuration.
    * __Logfire__ - You will need to create a free account and obtain your own write token.
    * __otel-desktop-viewer__: If you wish to use a locally-available OpenTelemetry collector, you can install the otel-desktop-viewer on your computer and simply route the trace data to that service.

