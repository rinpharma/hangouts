# rep-nix

Topic exploring reproducible R / data-science workflows with Nix.

This directory contains two sub-projects, each tracked as its own git
repository and wired into `hangouts` as a **git submodule**:

| Submodule | Remote |
| --- | --- |
| `demo_t_workflow` | `git@github.com:rinpharma/demo_t_workflow.git` |
| `demo_rix` | `git@github.com:rinpharma/demo_rix.git` |

## Working with the submodules

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
