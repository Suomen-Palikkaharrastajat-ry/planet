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
      pkgs.pocketbase
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

    # ── PocketBase local instance ────────────────────────────────────────────────
    # Runs PocketBase as a devenv process (start with: devenv up).
    # Data dir: pb_data/   Admin UI: http://127.0.0.1:8090/_/
    # Migrations are applied automatically on every start from pb_migrations/.
    processes.pocketbase.exec =
      "pocketbase serve --dir=./pb_data --http=127.0.0.1:8090 --migrationsDir=./pb_migrations";

    enterShell = ''
      echo ""
      echo "── planet dev environment ───────────────────────────"
      echo "  GHC:    $(ghc --version)"
      echo "  Cabal:  $(cabal --version | head -1)"
      echo "  Elm:    $(elm --version)"
      echo ""
      echo "  make build-all — fetch feeds + build Elm app"
      echo "  make watch     — watch + rebuild on changes"
      echo "  PocketBase: run 'devenv up' to start at http://127.0.0.1:8090"
      echo "    Set POCKETBASE_URL and POCKETBASE_API_KEY in .env (copy from .env.example)"
      echo ""
    '';
  };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
