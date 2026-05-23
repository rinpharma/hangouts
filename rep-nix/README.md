# Reproducible Data Science with Nix

🎥 [Recording](https://rinpharma.com/docs/hangout/recordings/rep_nix/) now available!

Ensuring reproducibility in data science workflows is paramount to the life sciences industry and beyond. A common workflow when using R or other languages such as Python is to manage package versions in a particular project with tools such as `{renv}` and `rv`, the focus of the [Package Management in R](https://rinpharma.com/docs/hangout/recordings/package_management/) session. But reproducibility in a data science environment goes beyond the R packages. Other important considerations include the system-level dependencies those packages depend on, which presents additional challanges. In this edition of the [R/Pharma](https://rinpharma.com) Hangout sessions, Bruno Rodrigues (head of the statistics department at the Ministry of Research and Higher Education in Luxembourg) joins us to showcase how the Nix package manager enables powerful capabilities to ensure reproducible environments in many levels, with a focus on the `{rix}`, `{rixpress}` and tne brand-new T language.

## Goals of the Session

* Introduce the Nix package manager
* Showcase how `rix}` provides a friendly wrapper to generating Nix configuration from an R session.
* Showcasee the power of `{rixpress}` for polygot pipelines that may include not only R, but also Python and Julia.
* Introduce the T language as a new domain-specific-language (DSL) for polygot data science

## Resources

* Session slides <https://b-rodrigues.github.io/repro_r_pharma/> and accompanying GitHub repository <https://github.com/b-rodrigues/repro_r_pharma/tree/main>
* `{rix}` documentation <https://docs.ropensci.org/rix/index.html>
* `{rixpress}` documentation <https://b-rodrigues.github.io/rixpress/>
* T language <https://tstats-project.org/index.html>

## Additional Examples

Inside this directory you will find two additonal repositories (captured as Git Submodules):

* [rinpharma/demo_rix](https://github.com/rinpharma/demo_rix): Using `{rix}` to manage R dependencies for Pharmaverse example R scripts.
* [rinpharma/demo_t_workflow](https://github.com/rinpharma/demo_t_workflow): Using the T language to run a clinical simulation pipeline originally created with the `{targets}` package.

If you are only interested in these example repositories, you can clone them individually to your local system. If you wish to use them within the overall `hangouts` repository, follow the instructions below:

### Working with the submodules

Fresh clone of `hangouts` (pulls submodule content too):

```sh
git clone --recurse-submodules git@github.com:rinpharma/hangouts.git
# or, if already cloned:
git submodule update --init --recursive
```

Make changes inside a submodule — treat it like a normal repo:

```sh
cd rep-nix/demo_t_workflow
# edit, then:
git add . && git commit -m "..."
git push
```

Record the new submodule commit in `hangouts`:

```sh
cd ../..                          # back to hangouts root
git add rep-nix/demo_t_workflow   # stages the new SHA pointer
git commit -m "Bump demo_t_workflow"
git push
```

Pull upstream changes for all submodules:

```sh
git submodule update --remote --merge
```
