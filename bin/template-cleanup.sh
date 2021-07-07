#!/usr/bin/env bash
# cleans up a child repository, removing unused files from the parent template.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(rm mv)
for dep in "${deps[@]}"; do
  hash "$dep" 2>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -ne 0 ]]; then
  [[ ${#missing[@]} -gt 1 ]] && { s="s"; }
  die "missing dep${s}: ${missing[*]}"
fi

# vars.
repo="$(basename "$PWD")" \
    || die "failed to get repository name"

# decide what to do, based on repository type.
if [[ "$repo" == *"-template"* ]]; then
  files=("docs")
else
  files=(
  ".github/workflows/dispatch.yml"
  ".github/workflows/template-cleanup.yml"
  "bin/dispatch.sh"
  "bin/rename-template.sh"
  "bin/template-cleanup.sh"
  "docs"
  )
fi

# remove files.
for thing in "${files[@]}"; do
  echo "##[group]Removing $thing"
  found=false
  [[ -d "$thing" ]] && { found=true; }
  [[ -f "$thing" ]] && { found=true; }
  [[ $found == false ]] \
    && { echo "failed to find $thing; does it exist?"; continue; }
  rm -rf "$thing" \
    || die "failed to remove $thing"
  echo "##[endgroup]"
done
