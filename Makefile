.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HLINT ?= hlint
FOURMOLU ?= fourmolu
PLANET_NIX ?= planet-nix

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

# ── Elm frontend ──────────────────────────────────────────────────────────────

.PHONY: elm-dev
elm-dev: ## Start Elm + Vite dev server (hot reload)
	cd elm-app && vite

ELM_APP_SOURCES := $(shell find elm-app/src -name '*.elm' ! -name 'Data.elm')
ELM_PACKAGE_SOURCES := $(shell find vendor/master-builder/packages -name '*.elm' -o -name '*.css' 2>/dev/null)

elm-app/src/Data.elm: planet planet.toml
	./planet

elm-app/src/.data-nix-stamp: planet.toml
	$(PLANET_NIX)
	touch $@

.PHONY: elm-tailwind-gen
elm-tailwind-gen: elm-app/.elm-tailwind/.stamp ## Generate typed Tailwind Elm modules into elm-app/.elm-tailwind/

elm-app/.elm-tailwind/.stamp: elm-app/elm.json elm-app/vite.config.mjs elm-app/main.css $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES)
	cd elm-app && elm-tailwind-classes gen
	mkdir -p elm-app/.elm-tailwind
	touch $@

elm-app/dist/.elm-stamp: elm-app/.elm-tailwind/.stamp $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES) elm-app/elm.json elm-app/vite.config.mjs elm-app/index.html elm-app/src/Data.elm elm-app/main.js elm-app/main.css
	cd elm-app && vite build
	touch $@

elm-app/dist/.elm-stamp-ci: elm-app/.elm-tailwind/.stamp $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES) elm-app/elm.json elm-app/vite.config.mjs elm-app/index.html elm-app/src/.data-nix-stamp elm-app/main.js elm-app/main.css
	cd elm-app && vite build
	touch $@

.PHONY: elm-build
elm-build: elm-app/dist/.elm-stamp ## Build the Elm app

.PHONY: elm-test
elm-test: elm-app/.elm-tailwind/.stamp elm-app/src/Data.elm ## Run Elm tests with generated Tailwind modules and generated feed data
	cd elm-app && elm-test

.PHONY: elm-check
elm-check: ## Check Elm formatting (no changes)
	cd elm-app && find src -name '*.elm' ! -name 'Data.elm' -print0 | xargs -0 elm-format --validate

.PHONY: elm-format
elm-format: ## Auto-format Elm source files
	cd elm-app && find src -name '*.elm' ! -name 'Data.elm' -print0 | xargs -0 elm-format --yes

# ── Haskell generator ─────────────────────────────────────────────────────────

HS_SOURCES := $(shell find src -name '*.hs') planet.cabal $(wildcard cabal.project*)

planet: $(HS_SOURCES)
	cabal build
	cp $$(cabal list-bin planet) $@

.PHONY: build
build: planet ## Build the Haskell generator executable

.PHONY: run
run: elm-app/src/Data.elm ## Run the planet generator to refresh generated data

.PHONY: run-bin
run-bin: ## Run the compiled executable directly
	./planet

.PHONY: repl
repl: ## Start the Haskell REPL
	cabal repl

.PHONY: cabal-check
cabal-check: ## Check the package for common errors
	cabal check

# ── Combined targets ──────────────────────────────────────────────────────────

.PHONY: dist-ci
dist-ci: elm-app/dist/.elm-stamp-ci ## Build CI-ready static output using the Nix-provided generator binary
	rm -rf build
	mkdir -p build
	cp -R elm-app/dist/. build/

.PHONY: build-all
build-all: planet elm-app/src/Data.elm elm-app/dist/.elm-stamp ## Full local build: generator + Elm app

.PHONY: watch
watch: ## Watch for changes in Haskell and Elm files and rebuild
	make run-bin
	find src planet.cabal planet.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make run-bin' &
	cd elm-app && elm-tailwind-classes gen && vite dev

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: check
check: ## Check formatting and run hlint (no changes)
	$(HLINT) src test
	$(MAKE) elm-check

.PHONY: test
test: check ## Run Haskell and Elm tests
	cabal test
	$(MAKE) elm-test

.PHONY: format
format: ## Auto-format Haskell and Elm source files
	find src test -name '*.hs' | xargs $(FOURMOLU) --mode inplace
	$(MAKE) elm-format
	treefmt

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts, output, and test artifacts
	cabal clean
	rm -rf public build planet .hpc *.html src/Main elm-app/.elm-tailwind elm-app/src/.data-nix-stamp
