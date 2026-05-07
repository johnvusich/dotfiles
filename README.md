# dotfiles

Bootstrap script for GitHub Codespaces used to maintain nf-core pipeline repositories (primarily [nf-core/circdna](https://github.com/nf-core/circdna)).

## Usage

```bash
# Normal run
./install.sh

# Preview actions without making changes
DRY_RUN=1 ./install.sh

# Pin a specific nf-core tools version
NF_CORE_VERSION=3.5.2 ./install.sh
```

## What `install.sh` sets up

| Tool | Notes |
|------|-------|
| Git identity & config | Name, email, aliases, editor (VS Code), push defaults |
| Shell aliases | `nfl`, `nfs`, `nftest`, `nfver`, `glog` — see below |
| Java (OpenJDK 17) | Skipped if already present (devcontainer ships with Java) |
| `pipx` | Package manager for isolated Python CLIs |
| `nf-core` tools | Pinned via `NF_CORE_VERSION` (default: 3.5.2) |
| `pre-commit` | For running nf-core lint hooks |
| Nextflow | Skipped if already present (devcontainer ships with Nextflow) |

## Shell aliases added to `~/.bashrc`

| Alias | Expands to |
|-------|-----------|
| `nfl` | `nf-core pipelines lint` |
| `nfs` | `nf-core pipelines sync` |
| `nftest` | `nextflow run . -profile test,singularity --outdir ./results` |
| `nfver` | Shows the `nf_core_version` from `.nf-core.yml` |
| `glog` | `git log --oneline --graph --decorate --all` |
| `gs` | `git status` |
| `ll` | `ls -lah --color=auto` |

## Important: Singularity, not Docker

The nf-core devcontainer does not support `-profile docker` inside Codespaces.
Always use `-profile singularity` (or the `nftest` alias above).

## Enabling in GitHub Codespaces

1. Go to **github.com → Settings → Codespaces → Dotfiles**
2. Check **"Automatically install dotfiles"**
3. Select this repository from the dropdown

Changes apply to new Codespaces only — not existing ones.
