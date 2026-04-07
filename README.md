# planet

`planet` aggregates feeds from the Suomen Palikkaharrastajat community and publishes them as a static Elm-powered site.

## Overview

The project combines:

- a Haskell generator that reads [`planet.toml`](/workspaces/planet/planet.toml), fetches feeds, and generates frontend data
- an Elm frontend in [`elm-app/`](/workspaces/planet/elm-app) that renders the aggregated output

Key generated outputs include [`elm-app/src/Data.elm`](/workspaces/planet/elm-app/src/Data.elm), [`elm-app/public/search-index.json`](/workspaces/planet/elm-app/public/search-index.json), [`elm-app/public/opml.xml`](/workspaces/planet/elm-app/public/opml.xml), and CI-ready builds in [`build/`](/workspaces/planet/build).

## Development Environment

This project uses `devenv` for both local development and CI.

```sh
make develop
make shell
```

You can also run one-off commands through `devenv`:

```sh
devenv shell -- make build-all
```

## Common Commands

| Command | What it does |
|---|---|
| `make shell` | Open the development shell |
| `make build` | Build the Haskell generator executable |
| `make run` | Refresh generated feed data |
| `make elm-build` | Build the Elm frontend |
| `make build-all` | Build the generator and Elm app together |
| `make elm-test` | Run Elm tests |
| `make test` | Run formatting checks plus Haskell and Elm tests |
| `make watch` | Run the generator and start Vite dev mode |
| `make dist-ci` | Produce the CI/deploy build in `build/` |
| `make clean` | Remove build artifacts |

## Project Structure

```text
elm-app/          Elm 0.19 SPA frontend
  src/            Elm source modules
  tests/          Elm unit tests
  public/         Static frontend assets
  packages/       Symlink to shared Elm packages in vendor/master-builder
src/              Haskell library + executable modules
test/             Haskell test suite
pkgs/             Nix-managed Node/Vite/Elm tooling manifest + lockfile
vendor/master-builder  Shared Elm design tokens and UI components
.github/workflows CI/CD workflows
```

## Shared Frontend Conventions

The frontend follows the Suomen Palikkaharrastajat design guide:

- https://logo.palikkaharrastajat.fi/
- https://logo.palikkaharrastajat.fi/brand.css

Shared Elm design tokens and UI components are exposed through the package symlink at [`elm-app/packages`](/workspaces/planet/elm-app/packages), which points to [`vendor/master-builder/packages`](/workspaces/planet/vendor/master-builder/packages).

Frontend tooling is managed through Nix, not `pnpm`:

- [`pkgs/package.json`](/workspaces/planet/pkgs/package.json)
- [`pkgs/package-lock.json`](/workspaces/planet/pkgs/package-lock.json)
- [`pkgs/npm-tools.nix`](/workspaces/planet/pkgs/npm-tools.nix)

## CI and Deployment

GitHub Actions builds and deploys the site through `devenv` using frozen Cabal resources and Nix-managed frontend tooling.

- [`deploy.yml`](/workspaces/planet/.github/workflows/deploy.yml)
- [`scheduled.yml`](/workspaces/planet/.github/workflows/scheduled.yml)

Human-facing usage lives here in `README.md`. Agent-specific development instructions live in [`AGENTS.md`](/workspaces/planet/AGENTS.md).
