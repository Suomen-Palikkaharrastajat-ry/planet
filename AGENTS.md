# AGENTS.md

## Purpose

This document defines how LLM coding agents must read, navigate, and safely modify the `planet` repository. It is the primary entry point for any agent-based task.

## 1. Source of Truth & Precedence

Your understanding and actions must be guided by the following artifacts, in this strict order of precedence:

1.  **Tests (`test/`)**: Define the verifiable, correct behavior of the application. **Tests are the ultimate source of truth.**
2.  **ADRs (`agents/adrs/`)**: Define the architectural constraints and non-negotiable rules.
3.  **User Stories (`agents/stories/`)**: Explain the "why" behind the features and define product intent.
4.  **Glossary (`agents/GLOSSARY.md`)**: Provides the canonical vocabulary for this project.
5.  **Inline Source Code Comments**: Provide context but are subordinate to the artifacts above.

## 2. Agent Self-Guidance Work Loop

Before making any changes, you **MUST** follow this work loop:

1.  **State Goal**: Clearly state the perceived goal of the task.
2.  **Locate Artifacts**: Identify and read all relevant tests, user stories, and ADRs related to the goal.
3.  **Identify Constraints**: List the specific architectural and behavioral constraints imposed by the artifacts.
5.  **Propose Strategy**: Formulate a minimal change strategy that respects all constraints.
5.  **Formalize Behavior (BDD)**: When adding or updating tests, consider expressing the desired behavior in a Given/When/Then format within the test's comments or the user story itself. Tests are the executable specification of behavior.
6.  **Update/Add Tests**: Before writing implementation code, add or update tests that codify the goal. Ensure they fail as expected.
6.  **Implement**: Write the code to make the new tests pass.
7.  **Verify**: Run all tests and re-evaluate your changes against the user stories and ADRs to ensure compliance.

## 3. Repository Map (Agent-Oriented)

- **`./AGENTS.md`**: **Your entry point.** Defines rules of engagement.
- **`./agents/README.md`**: Quick repository orientation (what it is, what it isn't).
- **`./agents/GLOSSARY.md`**: Canonical terminology. Use it to speak the project's language.
- **`./agents/adrs/`**: Architectural Decision Records (ADRs). These are your constraints.
- **`./agents/stories/`**: User Stories. This is the "why."
- **`./test/`**: Behavioral truth.
    - `test/Spec.hs`: Key unit and integration tests.
    - `test/TestSuite.hs`: Test suite entry point.
- **`./src/`**: Implementation.
    - `src/Planet.hs`: Main business logic orchestration.
    - `src/FeedParser.hs`: Configuration and feed data parsing.
    - `src/HtmlGen.hs`: HTML generation logic.
    - `src/Styles.hs` & `src/Scripts.hs`: Embedded CSS and JS.
    - `src/I18n.hs`: Internationalization logic.
    - `src/ElmGen.hs`: Generates Elm data modules from parsed feeds.
- **`./elm-app/`**: Interactive Elm-based viewer application.
    - `elm-app/src/Main.elm`: Application entry point and orchestration.
    - `elm-app/src/Types.elm`: Core type definitions.
    - `elm-app/src/DateUtils.elm`: Date formatting and grouping utilities.
    - `elm-app/src/View.elm`: UI rendering logic.
    - `elm-app/src/Data.elm`: Generated feed data (from Haskell).
    - `elm-app/tests/`: Comprehensive test suite for Elm modules.
- **`./planet.cabal`**: Project definition and dependencies.
- **`./planet.toml`**: Main configuration file.

## 4. Change Rules

- **Do not** modify application behavior without first adding or modifying a test in `test/`.
- **Do not** violate a constraint defined in an ADR. If a change requires this, you must first propose a new ADR.
- All code changes must be accompanied by corresponding updates to tests and, if necessary, documentation.
- All commit messages **MUST** follow the Conventional Commits specification outlined in `agents/adrs/ADR-0000-agent-guidance.md`.

## 5. Decision Escalation Rules

You **MUST STOP** and escalate to the user for guidance if you encounter any of the following situations:

- A requirement in a User Story conflicts with an existing test.
- A proposed change would violate a constraint in an ADR.
- The desired behavior is ambiguous, or there are multiple plausible interpretations.
- You are uncertain how to proceed.

**Escalation Procedure:**
1.  Clearly document the conflict or ambiguity.
2.  If possible, create a new failing test case that demonstrates the ambiguity.
3.  Present the situation to the user and ask for clarification. **Do not guess.**

## Agent Workflow & Best Practices

- **TODO files**: Project-specific `TODO.md` files may be in `.gitignore`. If you can't read them with the `read_file` tool, use `run_shell_command` with `cat`.
- **Building and Testing**: This project uses a `Makefile` for common tasks. Use `make test` to run the test suite and `make build` to build the project.
- **Proactive Refactoring**: After completing your primary task, review the codebase for potential refactoring opportunities that would improve maintainability and adherence to the project's ADRs.

## 6. Style Guide Compliance

This project follows the **Suomen Palikkaharrastajat ry** brand style guide.

- **Human-readable**: https://logo.palikkaharrastajat.fi/
- **Machine-readable (JSON-LD, authoritative)**: https://logo.palikkaharrastajat.fi/design-guide/index.jsonld
  - Colors: https://logo.palikkaharrastajat.fi/design-guide/colors.jsonld
  - Typography: https://logo.palikkaharrastajat.fi/design-guide/typography.jsonld
  - Spacing: https://logo.palikkaharrastajat.fi/design-guide/spacing.jsonld
  - Motion: https://logo.palikkaharrastajat.fi/design-guide/motion.jsonld
  - Logos: https://logo.palikkaharrastajat.fi/design-guide/logos.jsonld
  - Responsiveness: https://logo.palikkaharrastajat.fi/design-guide/responsiveness.jsonld

**When making any UI change**, you MUST:

1. **Check the JSON-LD spec first.** Any color, font, spacing, or animation value must come from a named design token — never hard-code raw hex values or pixel values directly in components.
2. **Use brand colors correctly:**
   - Primary brand color is `#05131D` (brand black), not blue.
   - Brand accent is `#F2CD37` (yellow) — only for CTAs/highlights, always paired with brand-black text.
   - Red `#C91A09` is for danger/error states only.
   - Tailwind token classes: `bg-brand`, `text-brand`, `border-brand`, `bg-brand-yellow`.
3. **Use Outfit font exclusively** (variable font, weight 100–900; OFL licensed). Never fall back to system-only fonts in designed output.
4. **Respect logo usage rules:**
   - Prefer SVG; use WebP with PNG fallback for raster formats.
   - Minimum size: 80px wide (square logo), 200px wide (horizontal logo).
   - 25% clear space on all four sides.
   - Never stretch, recolour, add shadows, or distort.
   - Do **not** use the animated logo variant when `prefers-reduced-motion: reduce` is set.
5. **Use named spacing tokens** (4px base: space-1 through space-16); never use arbitrary px values.
6. **Respect motion rules:** Animate `transform` and `opacity` only. Always wrap animations in `@media (prefers-reduced-motion: no-preference)`. Use `duration.fast` (150ms) for hover/focus, `duration.base` (300ms) for reveals, with `easing.standard` (`cubic-bezier(0.4, 0, 0.2, 1)`).
7. **Semantic colors over raw values:** Use the semantic token names (e.g., `background.page = #FFFFFF`, `background.subtle = #F9FAFB`, `border.default = #E5E7EB`) so changes propagate correctly.
8. **Page layout:** Every page wrapper uses `max-w-5xl mx-auto px-4` (1024px content width). Cards use `rounded-lg` (8px radius).
