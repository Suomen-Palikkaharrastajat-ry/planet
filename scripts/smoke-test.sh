#!/usr/bin/env bash
set -e

check_url() {
  local url="$1"
  curl -f --silent --show-error --output /dev/null "$url"
  echo "Smoke test passed: $url"
}

check_url "$SITE_URL"
check_url "$SITE_URL/fi/"
check_url "$SITE_URL/en/"
