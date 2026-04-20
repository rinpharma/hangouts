#https://gist.github.com/b-rodrigues/d427703e76a112847616c864551d96a1
library(rix)

rix(
  r_ver = "4.5.3",
  project_path = getwd(),
  r_pkgs = c(
    "shiny",
    "bsicons",
    "dplyr",
    "shinychat",
    "random.cdisc.data",
    "otel",
    "otelsdk",
    "plotly",
    "reactable",
    "pins"
  ),
  #system_pkgs = "quarto",
  git_pkgs = list(
    package_name = "ellmer",
    repo_url = "https://github.com/tidyverse/ellmer",
    commit = "35659d1d169c31eaa5908a234ebc3b2b2bc145dd"
  ),
  ide = "none",
  overwrite = TRUE
)
