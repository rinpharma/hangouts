#https://gist.github.com/b-rodrigues/d427703e76a112847616c864551d96a1
library(rix)

rix(
  r_ver = "4.5.3",
  project_path = getwd(),
  r_pkgs = c(
    "shiny",
    "bsicons",
    "dplyr",
    "duckdb",
    "querychat",
    "ellmer",
    "random.cdisc.data",
    "otelsdk",
    "plotly",
    "reactable",
    "pins"
  ),
  #system_pkgs = "quarto",
  ide = "none",
  overwrite = TRUE
)
