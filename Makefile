.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ── Vendor / submodules ──────────────────────────────────────────────────────

.PHONY: vendor
vendor: ## Init and update all git submodules to their pinned commits
	@# In CI environments (GitHub Actions, Netlify) SSH access is unavailable;
	@# rewrite git@github.com: to https://github.com/ so submodules clone via HTTPS.
	@[ -z "$$CI" ] || git config --global url."https://github.com/".insteadOf "git@github.com:"
	git submodule update --init

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
ELM_APP_SOURCES := $(shell find elm-app/src -name '*.elm' ! -name 'Data.elm')
ELM_PACKAGE_SOURCES := $(shell find vendor/master-builder/packages -name '*.elm' -o -name '*.css' 2>/dev/null)

planet: $(HS_SOURCES)
	cabal build
	cp $$(cabal list-bin planet) $@

.PHONY: build
build: planet ## Build the executable

elm-app/src/Data.elm: planet planet.toml
	./planet

elm-app/.elm-tailwind/.stamp: elm-app/elm.json elm-app/vite.config.mjs elm-app/src/main.css $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES)
	cd elm-app && elm-tailwind-classes gen
	mkdir -p elm-app/.elm-tailwind
	touch $@

.PHONY: run
run: elm-app/src/Data.elm ## Run the planet generator to update site

.PHONY: run-bin
run-bin: ## Run the compiled executable directly
	./planet

elm-app/dist/.build-stamp: elm-app/.elm-tailwind/.stamp $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES) elm-app/elm.json elm-app/vite.config.mjs elm-app/index.html elm-app/src/Data.elm
	cd elm-app && vite build
	touch $@

.PHONY: elm-build
elm-build: elm-app/dist/.build-stamp ## Build the Elm app

.PHONY: elm-test
elm-test: elm-app/.elm-tailwind/.stamp ## Run Elm tests with generated Tailwind modules
	cd elm-app && elm-test

.PHONY: dist-ci
dist-ci: build-all ## Build CI-ready static output
	rm -rf build
	mkdir -p build
	cp -R elm-app/dist/. build/

.PHONY: build-all
build-all: planet elm-app/src/Data.elm elm-app/dist/.build-stamp ## Build the entire project

.PHONY: watch
watch: ## Watch for changes in Haskell and Elm files and rebuild
	make run-bin
	find src planet.cabal planet.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make run-bin' &
	cd elm-app && elm-tailwind-classes gen && vite dev

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: test
test: check ## Run tests
	cabal test
	$(MAKE) elm-test

.PHONY: repl
repl: ## Start the REPL
	cabal repl

.PHONY: check
check: ## Check formatting and run hlint (no changes)
	hlint src test
	cd elm-app && elm-format --validate $(patsubst elm-app/%,%,$(ELM_APP_SOURCES))

.PHONY: cabal-check
cabal-check: ## Check the package for common errors
	cabal check

.PHONY: format
format: ## Auto-format Haskell and Elm source files
	find src test -name '*.hs' | xargs fourmolu --mode inplace
	cd elm-app && elm-format --yes $(patsubst elm-app/%,%,$(ELM_APP_SOURCES))
	treefmt

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts, output, and test artifacts
	cabal clean
	rm -rf public build planet .hpc *.html src/Main elm-app/.elm-tailwind
