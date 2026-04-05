# Packages vite CLI and elm-test CLI from the project's npm package-lock.json
# so the versions stay in sync with package.json.
#
# The derivation fetches npm deps in the Nix sandbox (--ignore-scripts skips
# elm-tooling and other binary-download postinstall hooks) and wraps the
# resulting Node.js scripts so the Nix-packaged elm is always found first
# on PATH and NODE_PATH points to the bundled node_modules for Vite resolution.
#
# How to update the hash after changing package-lock.json:
#   1. Set hash = pkgs.lib.fakeHash; below
#   2. Run `devenv shell` — the build fails with the correct sha256 in "got:"
#   3. Paste that sha256 here
{ pkgs }:
let
  # Strip the postinstall script so elm-tooling does not try to download
  # elm/elm-format inside the Nix sandbox (they come from Nix packages).
  patchedSrc = pkgs.runCommand "planet-npm-src"
    { nativeBuildInputs = [ pkgs.jq ]; }
    ''
      mkdir $out
      jq 'del(.scripts.postinstall)' ${./package.json} > $out/package.json
      cp ${./package-lock.json} $out/package-lock.json
    '';

  npmDeps = pkgs.fetchNpmDeps {
    name = "planet-npm-deps";
    src = patchedSrc;
    # Computed by building with pkgs.lib.fakeHash and reading the "got:" line.
    # To update: set back to pkgs.lib.fakeHash, run `devenv shell`, replace with
    # the sha256 printed in the error output.
    hash = "sha256-F4s7GHcGEVV5sZAyqf4XQNBKMP0VplBxVw1gXjaZp9E=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "planet-npm-tools";
  version = "1.0.0";

  src = patchedSrc;
  inherit npmDeps;

  nativeBuildInputs = [
    pkgs.nodejs_22
    pkgs.npmHooks.npmConfigHook
    pkgs.makeWrapper
  ];

  # npmConfigHook uses $npmDeps (read-only Nix store) as the npm cache for
  # fetcherVersion 1. npm tries to write to _cacache/tmp inside it → EACCES.
  # makeCacheWritable copies npmDeps to a writable tmpdir before npm ci.
  makeCacheWritable = "1";

  # npm rebuild (run by npmConfigHook after npm ci) does NOT have --ignore-scripts
  # by default. elm-test's postinstall calls elm-tooling install, which tries to
  # download binaries from the network and fails in the Nix sandbox.
  npmRebuildFlags = "--ignore-scripts";

  # elm-test depends on elm-tooling which tries to download Elm binaries from
  # the internet during postinstall. Stub it with a no-op before npm ci runs.
  postPatch = ''
    mkdir -p "$TMPDIR/fake-bin"
    printf '#!/bin/sh\nexec true\n' > "$TMPDIR/fake-bin/elm-tooling"
    chmod +x "$TMPDIR/fake-bin/elm-tooling"
    export PATH="$TMPDIR/fake-bin:$PATH"
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib
    cp -r node_modules $out/lib/

    # Patch broken tailwind-resolver default export (upstream bug in 0.3.x):
    # The minified bundle exports 'u1' which doesn't exist in the module.
    for f in \
      $out/lib/node_modules/tailwind-resolver/dist/index.mjs \
      $out/lib/node_modules/elm-tailwind-classes/node_modules/tailwind-resolver/dist/index.mjs; do
      if [ -f "$f" ]; then
        substituteInPlace "$f" --replace-quiet "u1 as default" "h1 as default"
      fi
    done

    # Patch elm-tailwind vite plugin: bundledReviewConfig points into the Nix
    # store (read-only). elm-review tries to mkdir 'suppressed/' inside the
    # config dir and gets EACCES. Fix: copy extractor to a writable tmpdir at
    # runtime so elm-review can write there. (fs is already imported in the file.)
    if [ -f "$out/lib/node_modules/elm-tailwind-classes/vite-plugin/index.js" ]; then
      substituteInPlace \
        "$out/lib/node_modules/elm-tailwind-classes/vite-plugin/index.js" \
        --replace-fail \
        "const bundledReviewConfig = path.resolve(__dirname, '..', 'extractor');" \
        "const bundledReviewConfig = (() => { const src = path.resolve(__dirname, '..', 'extractor'); const dst = path.join(process.env.TMPDIR || '/tmp', 'elm-tailwind-extractor'); try { fs.cpSync(src, dst, { recursive: true, force: true }); } catch(e) {} return dst; })();"
    fi

    # vite CLI
    # Entry point: node_modules/vite/bin/vite.js
    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/vite \
      --add-flags "$out/lib/node_modules/vite/bin/vite.js" \
      --prefix PATH : "$out/lib/node_modules/.bin" \
      --set NODE_PATH "$out/lib/node_modules"

    # elm-test CLI
    # Entry point: node_modules/elm-test/bin/elm-test
    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/elm-test \
      --add-flags "$out/lib/node_modules/elm-test/bin/elm-test" \
      --prefix PATH : "$out/lib/node_modules/.bin" \
      --prefix PATH : "${pkgs.elmPackages.elm}/bin" \
      --set NODE_PATH "$out/lib/node_modules"

    # elm-tailwind-classes CLI  (elm-tailwind-classes gen)
    # Entry point: node_modules/elm-tailwind-classes/vite-plugin/cli.js
    makeWrapper ${pkgs.nodejs_22}/bin/node $out/bin/elm-tailwind-classes \
      --add-flags "$out/lib/node_modules/elm-tailwind-classes/vite-plugin/cli.js" \
      --prefix PATH : "$out/lib/node_modules/.bin" \
      --set NODE_PATH "$out/lib/node_modules"

    runHook postInstall
  '';
}
