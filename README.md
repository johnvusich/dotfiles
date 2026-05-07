# dotfiles

This repository contains a bootstrap script for GitHub Codespaces used to maintain nf-core pipeline repositories.

## Usage

Run the installer from this repository root:

```bash
./install.sh
```

To preview actions without making changes:

```bash
DRY_RUN=1 ./install.sh
```

## What `install.sh` sets up

- Java runtime (OpenJDK 17)
- `pipx`
- `nf-core` CLI
- `pre-commit`
- `nextflow`
