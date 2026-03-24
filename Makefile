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

.PHONY: all
all: build-all ## Build the project

.PHONY: build-all
build-all: build ## Build the entire project
	cabal run
	cd elm-app && pnpm build

.PHONY: build
build: ## Build the executable
	cabal update
	cabal build
	cp $(shell cabal list-bin planet) ./planet

.PHONY: run
run: ## Run the planet generator to update site
	cabal run

.PHONY: run-bin
run-bin: ## Run the compiled executable directly
	./planet

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
