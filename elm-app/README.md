# elm-app

Interactive Elm frontend for `planet`.

## Development

Use the repo `devenv` shell. `elm-app/` no longer carries its own `package.json` or lockfile.

```bash
devenv shell
make elm-test
make watch
make elm-build
```

## Tooling model

- Node, Vite, `elm-test`, and `elm-tailwind-classes` come from [`pkgs/npm-tools.nix`](/workspaces/planet/pkgs/npm-tools.nix).
- `devenv.nix` exposes those tools and symlinks `node_modules` into the repo root and `elm-app/`.
- `elm-tailwind-classes gen` writes generated Elm modules to `elm-app/.elm-tailwind/`.

## Elm package layout

- `elm-app/packages/design-tokens` points to the shared design token package.
- `elm-app/packages/ui-components` points to the shared UI component package.
- `elm-app/elm.json` includes both package `src/` directories plus `.elm-tailwind/`.

## Styling guidance

- Prefer `DesignTokens.*` for token-backed values and shared vocabulary.
- Prefer `Component.*` modules when a shared component matches the UI need.
- Prefer generated `Tailwind`, `Tailwind.Theme`, and `Tailwind.Breakpoints` modules over raw class strings in new Elm code.
- Keep raw Tailwind class strings only in legacy areas or for utilities not yet covered by shared packages or generated modules.
