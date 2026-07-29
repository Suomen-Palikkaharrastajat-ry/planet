let
  mkTools = pkgs: pkgs.callPackage ./pkgs/npm-tools.nix { };

  # Haskell package set with this repo's local overrides (see overrides.nix).
  #
  # planet deliberately does not consume master-builder's statics-common: its
  # HtmlSanitizer sanitizes syndicated feed HTML, which is a different job from
  # the shared DescriptionHtml used by event-calendar and service-map.
  hpkgsFor =
    pkgs:
    pkgs.haskell.packages.ghc96.override {
      overrides = import ./overrides.nix { inherit pkgs; };
    };

  ci =
    { pkgs, ... }:
    let
      npmTools = mkTools pkgs;
      hpkgs = hpkgsFor pkgs;
      staticsPackage = hpkgs.callCabal2nix "planet" ./statics { };
    in
    {
      # Elm 0.19 tools
      languages.elm.enable = true;

      # Haskell (GHC + cabal + HLS via languages.haskell.enable)
      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;

      env.NODE_PATH = "${npmTools}/lib/node_modules";

      packages = [
        pkgs.cabal-install
        staticsPackage
        npmTools
        pkgs.nodejs_22
        hpkgs.hlint
        hpkgs.fourmolu
        pkgs.elmPackages.elm-review
        pkgs.elmPackages.elm-json
      ];

      enterShell = ''
        # Match the shell profile: expose the Nix-managed frontend toolchain
        # from both the repo root and elm-app/.
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules
      '';
    };

  shell =
    { pkgs, ... }:
    let
      npmTools = mkTools pkgs;
    in
    {
      # Elm 0.19 tools
      languages.elm.enable = true;

      # Haskell (GHC + cabal + HLS via languages.haskell.enable)
      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;

      packages = [
        pkgs.cabal-install
        pkgs.entr
        pkgs.git
        pkgs.nodejs_22
        pkgs.openssl
        pkgs.pkg-config
        pkgs.treefmt
        pkgs.zlib
        pkgs.elmPackages.elm-review
        pkgs.elmPackages.elm-json
        pkgs.haskell.packages.ghc96.hlint
        pkgs.haskell.packages.ghc96.fourmolu
        npmTools
      ];

      env.NODE_PATH = "${npmTools}/lib/node_modules";

      enterShell = ''
        # vite.config.mjs uses ESM imports, so we expose the Nix-managed
        # node_modules tree via symlinks as well as NODE_PATH.
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules

        echo ""
        echo "── planet dev environment ────────────────────────────────"
        echo "  GHC:    $(ghc --version)"
        echo "  Cabal:  $(cabal --version | head -1)"
        echo "  Elm:    $(elm --version)"
        echo "  Node:   $(node --version)"
        echo "  Vite:   $(vite --version)"
        echo ""
        echo "  make build-all  — build generator + Elm app"
        echo "  make dist-ci    — build CI/deploy output in build/"
        echo "  make watch      — watch generator inputs + run Vite"
        echo ""
      '';
    };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };

  profiles.ci.module = {
    imports = [ ci ];
  };
}
