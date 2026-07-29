.PHONY: help
help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

HLINT ?= hlint
FOURMOLU ?= fourmolu

# Generator binary used to regenerate elm-app/src/Data.elm and the OPML/search
# assets that Vite bundles.
#
#   default      build it from source with cabal → statics/planet
#   PLANET_NIX=1 use the Nix-built `planet` the ci devenv profile puts on PATH,
#                skipping the cabal build entirely (this is what CI does)
ifdef PLANET_NIX
PLANET := planet
PLANET_DEPS :=
else
PLANET := ./statics/planet
PLANET_DEPS := statics/planet
endif

# vite bundles vite.config.mjs into node_modules/.vite-temp before loading it,
# but node_modules is a symlink into the read-only Nix store. --configLoader
# runner loads the config directly and never writes that temp file.
VITE_FLAGS ?= --configLoader runner

# ── Vendor / submodules ──────────────────────────────────────────────────────

.PHONY: vendor
vendor: ## Init and update all git submodules to their pinned commits
	@# In CI environments (GitHub Actions, Netlify) SSH access is unavailable;
	@# rewrite git@github.com: to https://github.com/ so submodules clone via HTTPS.
	@[ -z "$$CI" ] || git config --global url."https://github.com/".insteadOf "git@github.com:"
	@# Fall back to a plain clone when this tree is not a git checkout (source
	@# tarball, vendored copy). The submodule directory itself always exists, so
	@# probe for a file inside it rather than for the directory.
	@if [ -d .git ]; then git submodule update --init; \
	elif [ ! -e vendor/master-builder/AGENTS.md ]; then \
		mkdir -p vendor && git clone https://github.com/Suomen-Palikkaharrastajat-ry/master-builder.git vendor/master-builder; \
	fi

# ── Development environment ──────────────────────────────────────────────────

.PHONY: shell
shell: ## Enter devenv shell
	devenv shell

# ── Elm frontend ──────────────────────────────────────────────────────────────

.PHONY: elm-dev
elm-dev: ## Start Elm + Vite dev server (hot reload)
	cd elm-app && vite

ELM_APP_SOURCES := $(shell find elm-app/src -name '*.elm' ! -name 'Data.elm')
ELM_PACKAGE_SOURCES := $(shell find vendor/master-builder/packages -name '*.elm' -o -name '*.css' 2>/dev/null)

elm-app/src/Data.elm: $(PLANET_DEPS) planet.toml
	$(PLANET)

.PHONY: elm-tailwind-gen
elm-tailwind-gen: elm-app/.elm-tailwind/.stamp ## Generate typed Tailwind Elm modules into elm-app/.elm-tailwind/

elm-app/.elm-tailwind/.stamp: elm-app/elm.json elm-app/vite.config.mjs elm-app/main.css $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES)
	cd elm-app && elm-tailwind-classes gen
	mkdir -p elm-app/.elm-tailwind
	touch $@

dist/.elm-stamp: elm-app/.elm-tailwind/.stamp $(ELM_APP_SOURCES) $(ELM_PACKAGE_SOURCES) elm-app/elm.json elm-app/vite.config.mjs elm-app/index.html elm-app/src/Data.elm elm-app/main.js elm-app/main.css
	cd elm-app && vite build $(VITE_FLAGS)
	touch $@

.PHONY: elm-build
elm-build: dist/.elm-stamp ## Build the Elm app

.PHONY: elm-test
elm-test: elm-app/.elm-tailwind/.stamp elm-app/src/Data.elm ## Run Elm tests with generated Tailwind modules and generated feed data
	cd elm-app && elm-test

.PHONY: elm-check
elm-check: ## Check Elm formatting + elm-review (no changes)
	cd elm-app && find src -name '*.elm' ! -name 'Data.elm' -print0 | xargs -0 elm-format --validate
	$(MAKE) elm-review

.PHONY: elm-review
elm-review: elm-app/.elm-tailwind/.stamp elm-app/src/Data.elm ## Run elm-review with the shared LlmAgent rules from vendor/master-builder
	cd elm-app && elm-review --config ../review

.PHONY: elm-format
elm-format: ## Auto-format Elm source files
	cd elm-app && find src -name '*.elm' ! -name 'Data.elm' -print0 | xargs -0 elm-format --yes

# ── Haskell generator ─────────────────────────────────────────────────────────

HS_SOURCES := $(shell find statics/src statics/app -name '*.hs') statics/planet.cabal $(wildcard cabal.project*)

statics/planet: $(HS_SOURCES)
	cabal build planet
	cp $$(cabal list-bin planet) $@

.PHONY: statics-build
statics-build: statics/planet ## Build Haskell static generator

.PHONY: statics-test
statics-test: ## Run Haskell tests
	cabal test planet-tests

.PHONY: statics-check
statics-check: ## Lint Haskell source (hlint)
	$(HLINT) statics/src/ statics/app/ statics/tests/

.PHONY: statics-format
statics-format: ## Auto-format Haskell source (fourmolu)
	find statics/src statics/app statics/tests -name '*.hs' | xargs $(FOURMOLU) --mode inplace

.PHONY: build
build: elm-build ## Production build of Elm SPA

.PHONY: run
run: statics/planet ## Build and run the planet generator to refresh generated data
	./statics/planet

.PHONY: repl
repl: ## Start the Haskell REPL
	cabal repl planet

.PHONY: cabal-check
cabal-check: ## Check the package for common errors
	cd statics && cabal check

# ── Combined targets ──────────────────────────────────────────────────────────

.PHONY: dist
dist: dist/.elm-stamp ## Full production build: generator + Elm app → dist/
	$(MAKE) dist-assemble

.PHONY: dist-ci
dist-ci: ## CI build: same as dist, using the Nix-provided generator binary
	$(MAKE) dist PLANET_NIX=1

.PHONY: dist-assemble
dist-assemble: ## Duplicate index.html into a directory per OPML feed group
	for opml in dist/opml.*.xml; do \
		[ -e "$$opml" ] || continue; \
		group="$${opml#dist/opml.}"; \
		group="$${group%.xml}"; \
		mkdir -p "dist/$$group"; \
		cp dist/index.html "dist/$$group/index.html"; \
	done

.PHONY: watch
watch: ## Watch for changes in Haskell and Elm files and rebuild
	make run
	find statics/src statics/app statics/planet.cabal planet.toml -name "*.hs" -o -name "*.cabal" -o -name "*.toml" | entr -s 'make run' &
	cd elm-app && elm-tailwind-classes gen && vite dev

# ── Test & quality ────────────────────────────────────────────────────────────

.PHONY: check
check: elm-check statics-check ## Run all linting/formatting checks

.PHONY: test
test: elm-test statics-test ## Run all tests (Elm + Haskell)

.PHONY: format
format: elm-format statics-format ## Auto-format all code
	treefmt

# ── Cleanup ───────────────────────────────────────────────────────────────────

.PHONY: clean
clean: ## Clean build artifacts, output, and test artifacts
	cabal clean
	rm -rf public dist statics/planet .hpc *.html elm-app/.elm-tailwind
