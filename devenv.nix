let
  ci =
    { pkgs, ... }:
    let
      hpkgs = pkgs.haskell.packages.ghc96.override {
        overrides =
          self: super: {
            "htoml-megaparsec" =
              pkgs.haskell.lib.dontCheck
                (pkgs.haskell.lib.doJailbreak
                  (pkgs.haskell.lib.markUnbroken super."htoml-megaparsec"));
          };
      };
      npmTools = pkgs.callPackage ./pkgs/npm-tools.nix { };
      planetPackage = hpkgs.callCabal2nix "planet" ./. { };
      planetCommand = pkgs.writeShellScriptBin "planet-nix" ''
        exec ${planetPackage}/bin/planet "$@"
      '';
      ciTools = pkgs.symlinkJoin {
        name = "planet-ci-tools";
        paths = [
          planetCommand
          npmTools
        ];
      };
    in
    {
      languages.elm.enable = true;

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;

      env.NODE_PATH = "${npmTools}/lib/node_modules";

      packages = [
        ciTools
        pkgs.cabal-install
        pkgs.nodejs_22
        hpkgs.ghc
        hpkgs.hlint
        hpkgs.fourmolu
      ];

      enterShell = ''
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules
      '';
    };

  shell =
    { pkgs, ... }:
    let
      npmTools = pkgs.callPackage ./pkgs/npm-tools.nix { };
    in
    {
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

      languages.haskell.enable = true;
      languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
      languages.elm.enable = true;

      env.NODE_PATH = "${npmTools}/lib/node_modules";

      enterShell = ''
        ln -sfn "${npmTools}/lib/node_modules" node_modules
        ln -sfn "${npmTools}/lib/node_modules" elm-app/node_modules

        echo ""
        echo "── planet dev environment ───────────────────────────"
        echo "  GHC:    $(ghc --version)"
        echo "  Cabal:  $(cabal --version | head -1)"
        echo "  Elm:    $(elm --version)"
        echo "  Node:   $(node --version)"
        echo "  Vite:   $(vite --version)"
        echo ""
        echo "  make build-all — fetch feeds + build Elm app"
        echo "  make elm-test  — run Elm tests with generated tailwind modules"
        echo "  make watch     — watch + rebuild on changes"
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
