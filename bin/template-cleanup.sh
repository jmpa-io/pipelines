#!/usr/bin/env bash
# cleans up a child repository, removing unused files from the parent template.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(rm)
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

# determine "things" to remove.
files=(
  "bin/dispatch.sh"
  "bin/template-cleanup.sh"
  "docs"
)
if [[ "$repo" == *"-template"* ]]; then
  files=(
    "docs"
  )
fi

# remove "things".
for thing in "${files[@]}"; do
  found=false
  [[ -d "$thing" ]] && { found=true; }
  [[ -f "$thing" ]] && { found=true; }
  [[ $found == false ]] \
    && die "failed to find $thing; does it exist?"
  echo rm -rf "$thing" \
    || die "failed to remove $thing"
done


  # # while we're here, update all the files with
  # # the new template name.

  # files=$(find . -type f \
  #   -not -path "$0" \
  #   -not -path "./.git/*" \
  #   -not -name '*dispatch.*' \
  #   -not -name '*template-cleanup.*')
