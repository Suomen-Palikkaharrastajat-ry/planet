#!/usr/bin/env bash
set -e

check_url() {
  local url="$1"
  curl -f --silent --show-error --output /dev/null "$url"
  echo "Smoke test passed: $url"
}

SITE_URL="${SITE_URL%/}"

check_url "$SITE_URL"
check_url "$SITE_URL/fi/"
# en is hidden in config.toml, so /en/ is expected to 404 until it is published.
