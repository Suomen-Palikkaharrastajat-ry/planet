# Thin wrapper around the shared npm-tools builder in master-builder.
# package.json / package-lock.json stay in this directory; the derivation
# logic lives in vendor/master-builder/pkgs/mk-npm-tools.nix.
#
# How to update the hash after changing package-lock.json:
#   1. Set hash = pkgs.lib.fakeHash; below
#   2. Run `devenv shell` — the build fails with the correct sha256 in "got:"
#   3. Paste that sha256 here
{ pkgs }:
import ../vendor/master-builder/pkgs/mk-npm-tools.nix {
  inherit pkgs;
  name = "planet";
  src = ./.;
  hash = "sha256-F4s7GHcGEVV5sZAyqf4XQNBKMP0VplBxVw1gXjaZp9E=";
}
