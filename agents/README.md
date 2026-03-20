# Repository Orientation Index for Agents

## 1. What This System Is

This repository contains the source code for `planet`, a Haskell CLI tool that aggregates RSS/Atom feeds into a static, single-page HTML overview. Additionally, it includes an interactive Elm-based web viewer for displaying the aggregated content in a modern, responsive interface.

## 2. What This System Is NOT

- It is **not** a dynamic web server.
- It is **not** a content management system (CMS).
- It does **not** have a database.
- It does **not** handle user accounts or interactions.

## 3. Core Invariants

- **Single-File Output**: The primary output MUST be a single, self-contained `public/index.html` file with embedded CSS and JS.
- **Configuration Driven**: All content and primary settings (title, feeds, locale) MUST be driven by the `planet.toml` file.
- **Stateless Execution**: Each run is independent and generates the site from scratch.

## 4. How to Get Started (Agent Reading Order)

1.  **Start Here**: Begin with `AGENTS.md` to understand the rules of engagement and the project's structure from an agent's perspective.
2.  **Understand the Architecture**: Review the ADRs in `agents/adrs/` to grasp the key architectural decisions and constraints.
3.  **Understand the "Why"**: Read the user stories in `agents/stories/` to understand the intended features and user-facing behavior.
4.  **Understand the "What"**: Examine the tests in `test/` (especially `test/Spec.hs`) to see the concrete, verifiable behaviors that are considered correct.
    - For the Elm application, review `elm-app/tests/` for frontend-specific tests.
5.  **Understand the "How"**: Finally, read the implementation in `src/`.
    - `src/Planet.hs`: The main orchestration logic.
    - `src/FeedParser.hs`: Handles `planet.toml` parsing and feed data extraction.
    - `src/HtmlGen.hs`: Constructs the final HTML output.
    - `src/ElmGen.hs`: Generates Elm data modules from parsed feeds.
    - For the Elm application: `elm-app/src/Main.elm`, `elm-app/src/Types.elm`, `elm-app/src/DateUtils.elm`, `elm-app/src/View.elm`.

**Remember the Precedence:** Tests > ADRs > User Stories > Implementation Comments.

---

## 5. PocketBase

Phase 1 introduces PocketBase as a persistent item store. See `agents/adrs/ADR-0001-pocketbase.md` for the full rationale.

### Quick start (local development)

1. **Copy the env example:**
   ```sh
   cp .env.example .env
   ```

2. **Start PocketBase** (two options):
   - Via devenv (recommended): `devenv up`  — runs PocketBase at `http://127.0.0.1:8090`
   - Via Makefile: `make pb-dev`  — same, but outside devenv

3. **Open the Admin UI:** `http://127.0.0.1:8090/_/`
   - First run: create a superuser account when prompted.

4. **Generate an API token:** Admin UI → Settings → API Tokens → Create token.

5. **Fill in `.env`:**
   ```dotenv
   POCKETBASE_URL=http://127.0.0.1:8090
   POCKETBASE_API_KEY=<paste token here>
   ```

6. **Apply migrations:**
   ```sh
   make pb-migrate
   ```
   This creates the `feed_items` collection.

7. **Run the generator:**
   ```sh
   make run
   ```
   Items are synced to PocketBase; `Data.elm` is built from the PocketBase catalogue.

### Environment variables

| Variable | Required | Description |
|---|---|---|
| `POCKETBASE_URL` | No | Base URL of the PocketBase instance (e.g. `http://127.0.0.1:8090`). Omit to skip sync and use raw feed data. |
| `POCKETBASE_API_KEY` | No | Superuser API token (PocketBase ≥ 0.22). Generate in Admin UI → Settings → API Tokens. |

Both variables are loaded automatically from `.env` by devenv (`dotenv.enable = true`).
Without them, the build falls back to raw feed data (backwards-compatible, no crash).

### Makefile targets

| Target | Description |
|---|---|
| `make pb-dev` | Start a local PocketBase server (`pb_data/` as data directory) |
| `make pb-migrate` | Apply pending migrations from `pb_migrations/` |

### Integration tests

Integration tests for PocketBase require `POCKETBASE_URL` to be set and a live instance running. They are automatically skipped when the variable is absent, so **unit tests must always pass without PocketBase**.

### CI invariant

The build **must succeed and fall back to raw feed data** when `POCKETBASE_URL` is absent. This is a hard invariant enforced by the test suite (`make test` passes with no PocketBase configured).
