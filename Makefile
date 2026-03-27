.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Development environment ──────────────────────────────────────────────────

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

.PHONY: develop
develop: devenv.local.nix devenv.local.yaml ## Bootstrap opinionated development environment
	devenv shell --profile=devcontainer -- code .

devenv.local.nix:
	cp devenv.local.nix.example devenv.local.nix

devenv.local.yaml:
	cp devenv.local.yaml.example devenv.local.yaml

# ── Build ─────────────────────────────────────────────────────────────────────

HS_SOURCES := $(shell find src -name '*.hs') planet.cabal $(wildcard cabal.project*)

planet: $(HS_SOURCES)
	cabal build
	cp $$(cabal list-bin planet) $@

.PHONY: build
build: planet ## Build the executable

elm-app/src/Data.elm: planet planet.toml
	./planet

.PHONY: run
run: elm-app/src/Data.elm ## Run the planet generator to update site

.PHONY: run-bin
run-bin: ## Run the compiled executable directly
	./planet

elm-app/dist/.build-stamp: $(shell find elm-app/src -name '*.elm') elm-app/elm.json elm-app/package.json elm-app/src/Data.elm
	cd elm-app && npm run build
	touch $@

.PHONY: elm-build
elm-build: elm-app/dist/.build-stamp ## Build the Elm app

.PHONY: build-all
build-all: planet elm-app/src/Data.elm elm-app/dist/.build-stamp ## Build the entire project

.PHONY: watch
watch: ## Watch for changes in Haskell and Elm files and rebuild
	make run-bin
	find src planet.cabal planet.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make run-bin' &
	cd elm-app && pnpm dev

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: test
test: check ## Run tests
	cabal test

.PHONY: repl
repl: ## Start the REPL
	cabal repl

.PHONY: check
check: ## Check formatting and run hlint (no changes)
	hlint src tests
	cd elm-app && elm-format --validate src/

.PHONY: cabal-check
cabal-check: ## Check the package for common errors
	cabal check

.PHONY: format
format: ## Auto-format Haskell and Elm source files
	find src tests -name '*.hs' | xargs fourmolu --mode inplace
	cd elm-app && elm-format --yes src/

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts, output, and test artifacts
	cabal clean
	rm -rf public planet .hpc *.html src/Main
