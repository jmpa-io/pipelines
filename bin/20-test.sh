#!/usr/bin/env bash
# tests everything!

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(go grep)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  s=""; [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# test.
echo "##[group]Testing Go."
go test -short -coverprofile=coverage.txt -covermode=atomic \
  "$(go list ./... | grep "/depot/")" \
  && go tool cover -func=coverage.txt
echo "##[endgroup]"
