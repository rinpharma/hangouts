# Package Management in R

🎮 [Recording](https://rinpharma.com/docs/hangout/recordings/package_management/) now available! 

A foundational strength of the R language is the vast ecosystem of packages available that cover a wide array of statistical analysis techniques, data processing, innovative web application development, and much more. With the increased importance of R in the life sciences industry, it is more important than ever to have effective tools for managing these packages. In this edition of the [R/Pharma](https://rinpharma.com) Hangout sessions, we take a deeper look at popular package management tools in R with a panel of the tool authors and industry experts to share best practices and advice for adopting these frameworks for your next project.

## Goals of the Session

This session will utilize a collection of R programs available from the [Pharmaverse examples](https://pharmaverse.github.io/examples) repository to demonstrate using the [`{renv}`](https://rstudio.github.io/renv/index.html) package and the newly-released [`{rv}`](https://a2-ai.github.io/rv-docs) utility to manage R packages utilized in the scripts. Specifically we will use scripts from these Pharmaverse examples:

* Creation of the SDTM demographic (`DM`) domain: <https://pharmaverse.github.io/examples/sdtm/dm.html>
* Creation of the ADaM analysis dataset (`ADSL`) domain: <https://pharmaverse.github.io/examples/adam/adsl.html>
* Creation of a Demographic summary table: <https://pharmaverse.github.io/examples/tlg/demographic.html>

Below are the concepts we will illustrate in the session (time permitting):

* Starting a collection of scripts that load packages from the default R library, how to initialize each framework to take control of the package dependencies from that point on.
* Adding new packages iteratively throughout the lifecycle of development.
* Ensuring regular maintenance of the package library metadata.
* Key differences in the philosophies between `{renv}` and `rv`.
* Effective principles for collaboration in a team environment with version control.

## Resources

* rig: The R installation manager <https://github.com/r-lib/rig?tab=readme-ov-file#id-macos-installer>
* renv: Project environments for R <https://rstudio.github.io/renv/index.html>
* rv: A declarative R package manager <https://a2-ai.github.io/rv-docs>
* Pharmaverse examples <https://pharmaverse.github.io/examples>
* The R-Podcast Episode 32: RStudio's Big Move and Kevin Ushey <https://r-podcast.org/032-rsconf2020-part1/>

## Assorted Snippets

* One-liner for printing a space-delimited list of packages discovered by `{renv}`:

```
Rscript -e "renv::dependencies(quiet = FALSE)[['Package']] |> paste(collapse = ' ') |> cat()"
```

* Using the `rstudioapi::viewer()` function to render a web page in Positron or RStudio (note that not all web pages render correctly):

```r
rstudioapi::viewer("https://pharmaverse.github.io/examples")
```

