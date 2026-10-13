# planet

`planet` aggregates feeds from the Suomen Palikkaharrastajat community and publishes them as a static Elm-powered site.


## Overview

The project combines:

- a Haskell generator that reads [`planet.toml`](/workspaces/planet/planet.toml), fetches feeds, and generates frontend data
- an Elm frontend in [`elm-app/`](/workspaces/planet/elm-app) that renders the aggregated output

Key generated outputs include [`elm-app/src/Data.elm`](/workspaces/planet/elm-app/src/Data.elm), [`elm-app/public/search-index.json`](/workspaces/planet/elm-app/public/search-index.json), [`elm-app/public/opml.xml`](/workspaces/planet/elm-app/public/opml.xml), and CI-ready builds in [`dist/`](/workspaces/planet/dist).

## Development Environment

This project uses `devenv` for both local development and CI.

```sh
make develop
make shell
```

You can also run one-off commands through `devenv`:

```sh
devenv shell -- make dist
```

## Common Commands

| Command | What it does |
|---|---|
| `make shell` | Open the development shell |
| `make build` | Build the Haskell generator executable |
| `make run` | Refresh generated feed data |
| `make elm-build` | Build the Elm frontend |
| `make dist` | Build the generator and Elm app together → dist/ |
| `make elm-test` | Run Elm tests |
| `make test` | Run formatting checks plus Haskell and Elm tests |
| `make watch` | Run the generator and start Vite dev mode |
| `make dist-ci` | Produce the CI/deploy build in `dist/` |
| `make clean` | Remove build artifacts |

## Project Structure

```text
elm-app/          Elm 0.19 SPA frontend
  src/            Elm source modules
  tests/          Elm unit tests
  public/         Static frontend assets
  packages/       Symlink to shared Elm packages in vendor/master-builder
statics/src/      Haskell library modules
statics/app/      Haskell executable entry point
statics/tests/    Haskell test suite
pkgs/             Nix-managed Node/Vite/Elm tooling manifest + lockfile
vendor/master-builder  Shared Elm design tokens and UI components
.github/workflows CI/CD workflows
```

## Configuration and Translations

The site describes itself in [`config.toml`](config.toml): URL, title,
description, languages, and the app's own settings under `[app]`. It is layered
on the family defaults of the hub; the format is documented in
[`vendor/master-builder/docs/site-config.md`](vendor/master-builder/docs/site-config.md).

- Text in the default language (Finnish) sits directly in a section; English
  goes in a sub-table such as `[site.en]`; the app's own text sits in
  `[app.strings]` and `[app.en.strings]`.
- Vite generates the document head and `site.webmanifest` from it, so
  `elm-app/index.html` carries no title, description or icon tags.
- Two committed files are derived from it: `elm-app/tests/SiteFixture.elm`
  and `statics/src/SiteConfig.hs` (used by the generator). After editing
  `config.toml`, run `make site-config`; `make site-config-check` (part of
  `make elm-check` and of CI) fails when they are stale.
- Interface text lives in `elm-app/src/I18n.elm`, per language. Views take a
  `Lang` and contain no text of their own; the same check fails on Finnish
  text outside translations. To add a string, add a key (or a function, when
  the wording depends on a number) with its Finnish and English text.
- A visitor switches language with the footer link or `?lang=en`.

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
