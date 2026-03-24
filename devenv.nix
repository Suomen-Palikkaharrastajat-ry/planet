{ pkgs, ... }:

let
  shell = { pkgs, ... }: {
    # https://devenv.sh/packages/
    packages = [
      pkgs.entr
      pkgs.git
      pkgs.nodejs
      pkgs.openssl
      pkgs.pkg-config
      pkgs.treefmt
      pkgs.zlib
      pkgs.elmPackages.elm-review
      pkgs.elmPackages.elm-json
      pkgs.haskell.packages.ghc96.hlint
      pkgs.haskell.packages.ghc96.fourmolu
    ];

    # https://devenv.sh/languages/
    languages.haskell.enable = true;
    languages.haskell.package = pkgs.haskell.packages.ghc96.ghc;
    languages.elm.enable = true;
    languages.javascript.enable = true;
    languages.javascript.pnpm.enable = true;

    dotenv.enable = true;

    enterShell = ''
      echo ""
      echo "── planet dev environment ───────────────────────────"
      echo "  GHC:    $(ghc --version)"
      echo "  Cabal:  $(cabal --version | head -1)"
      echo "  Elm:    $(elm --version)"
      echo ""
      echo "  make build-all — fetch feeds + build Elm app"
      echo "  make watch     — watch + rebuild on changes"
      echo ""
    '';
  };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
