# ADR-0001: PocketBase as the Persistent Item Store

**Status:** Accepted
**Date:** 2026-03-19

---

## Context

The planet aggregator fetches RSS/Atom feeds on every run and generates the site from the raw HTTP responses. This means items vanish from the output the moment a feed goes offline, removes old entries, or the aggregator is run infrequently. Historical persistence is needed to:

- Keep items alive even when the upstream feed truncates its history.
- Enable future curation workflows (pinning, hiding, tagging).
- Support pagination over large datasets without holding everything in memory.

## Decision

We introduce **PocketBase ≥ 0.22** as a lightweight, embedded SQLite-backed REST database.

### Why PocketBase ≥ 0.22?

Version 0.22 added first-class **API tokens** (superuser bearer tokens) that allow authentication without an interactive email/password flow. This is critical for automated pipeline use: the Haskell process reads `POCKETBASE_API_KEY` from the environment and attaches it as a `Bearer` token—no session management required.

### Why not PostgreSQL / SQLite directly / another service?

| Option | Reason rejected |
|--------|----------------|
| PostgreSQL | Heavyweight for a small LEGO club site; requires a separate server process and schema migrations tooling |
| SQLite directly from Haskell | Adds `persistent`/`esqueleto` or raw FFI complexity; no REST API for future tooling |
| Supabase / Firebase | External SaaS with pricing risk and data sovereignty concerns |
| PocketBase | Single binary, zero-config, built-in REST API + UI, SQLite-backed, MIT licensed |

## Consequences

### Positive
- Items survive feed outages: once synced, they remain queryable.
- The PocketBase Admin UI provides a no-code curation interface out of the box.
- Migration files (`pb_migrations/`) provide reproducible schema management.
- The pipeline degrades gracefully: if `POCKETBASE_URL` is not set, the build falls back to raw feed data (backwards compatible).

### Negative
- Adds an external runtime dependency (PocketBase binary) to production and development.
- Integration tests require a live PocketBase instance; they are skipped in CI unless `POCKETBASE_URL` is set.
- Schema changes require a migration file and a running PocketBase instance to apply.

## Implementation

- PocketBase version: **0.22+** (exact version pinned by the operator).
- Authentication: `POCKETBASE_API_KEY` environment variable (superuser API token).
- Base URL: `POCKETBASE_URL` environment variable (e.g. `http://localhost:8090`).
- Collection: `feed_items` (see `pb_migrations/001_create_feed_items.js`).
- Haskell modules: `src/PocketBase.hs` (HTTP client), `src/PocketBaseSync.hs` (upsert logic).
