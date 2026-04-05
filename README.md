# planet

`planet` aggregates feeds from the Suomen Palikkaharrastajat community and publishes them as a static Elm-powered site.

It combines:

- a Haskell CLI that fetches and transforms feed data
- an Elm frontend that renders the aggregated output

## What It Does

The project reads feed definitions from [`planet.toml`](/workspaces/planet/planet.toml), fetches content from those feeds, and builds:

- an Elm data module for the frontend
- a search index
- an OPML export
- a static frontend build

## Requirements

This project uses `devenv` for development and CI.

Recommended setup:

- Nix
- devenv

## Getting Started

Bootstrap local files if needed:

```sh
make develop
```

Enter the shell:

```sh
make shell
```

Or run one-off commands through `devenv`:

```sh
devenv shell -- make build-all
```

## Common Commands

From the repo root:

| Command | What it does |
|---|---|
| `make shell` | Open the development shell |
| `make build` | Build the Haskell CLI |
| `make run` | Refresh generated feed data |
| `make elm-build` | Build the Elm frontend |
| `make build-all` | Run the full local build |
| `make elm-test` | Run Elm tests |
| `make test` | Run formatting checks plus Haskell and Elm tests |
| `make watch` | Run the generator and start Vite dev mode |
| `make dist-ci` | Produce the CI/deploy build in `build/` |
| `make clean` | Remove build artifacts |

## Build Outputs

Important generated outputs include:

- [`elm-app/src/Data.elm`](/workspaces/planet/elm-app/src/Data.elm)
- [`elm-app/public/search-index.json`](/workspaces/planet/elm-app/public/search-index.json)
- [`elm-app/public/opml.xml`](/workspaces/planet/elm-app/public/opml.xml)
- [`elm-app/dist/`](/workspaces/planet/elm-app/dist)
- [`build/`](/workspaces/planet/build) in CI-oriented builds

## Frontend Tooling

Frontend tooling is managed through Nix, not `pnpm`.

- Node/Vite/Elm-related packages live in [`pkgs/package.json`](/workspaces/planet/pkgs/package.json)
- the lockfile is [`pkgs/package-lock.json`](/workspaces/planet/pkgs/package-lock.json)
- wrappers are built by [`pkgs/npm-tools.nix`](/workspaces/planet/pkgs/npm-tools.nix)

`devenv` creates `node_modules` symlinks automatically for the repo root and `elm-app/`.

## Reproducible Haskell Builds

Haskell dependency resolution is pinned with:

- [`cabal.project`](/workspaces/planet/cabal.project)
- [`cabal.project.freeze`](/workspaces/planet/cabal.project.freeze)

If you change Haskell dependencies, refresh the freeze file before committing.

## Design System

The frontend follows the Suomen Palikkaharrastajat design guide:

- https://logo.palikkaharrastajat.fi/
- https://logo.palikkaharrastajat.fi/brand.css

Shared Elm design tokens and UI components are vendored through:

- `elm-app/packages/design-tokens`
- `elm-app/packages/ui-components`

## CI and Deployment

GitHub Actions builds and deploys the site through `devenv` using frozen Cabal resources and Nix-managed frontend tooling.

Relevant workflows:

- [`deploy.yml`](/workspaces/planet/.github/workflows/deploy.yml)
- [`scheduled.yml`](/workspaces/planet/.github/workflows/scheduled.yml)

## For Contributors Using AI Tools

Human-facing usage lives here in `README.md`.

Agent-specific development instructions live in [`AGENTS.md`](/workspaces/planet/AGENTS.md).
