{
  pkgs,
  inputs,
  ...
}:

let
  stable = import inputs.nixpkgs-stable {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
    };
  };
  shell = { pkgs, ... }: {
    # https://devenv.sh/packages/
    packages = [
      pkgs.elm-land
      pkgs.elmPackages.elm
      pkgs.elmPackages.elm-format
      pkgs.elmPackages.elm-language-server
      pkgs.entr
      pkgs.git
      pkgs.nodejs
      pkgs.openssl
      pkgs.pkg-config
      pkgs.treefmt
      pkgs.zlib
      stable.cabal-install
      stable.fourmolu
      stable.hlint
      stable.haskell.packages.ghc96.haskell-language-server
    ];

    # https://devenv.sh/languages/
    languages.haskell.enable = true;
    languages.haskell.package = stable.haskell.compiler.ghc96;
    languages.haskell.stack.enable = true;
    languages.haskell.languageServer = stable.haskell.packages.ghc96.haskell-language-server;
    languages.elm.enable = true;

    enterShell = ''
      git --version
      stack --version
    '';

    dotenv.disableHint = true;
  };
in
{
  profiles.shell.module = {
    imports = [ shell ];
  };
}
