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

# read parent repo.
# NOTE: doing this, since it's not safe to modify
#       a running bash script.
parentRepo="${PARENT_TEMPLATE}"
[[ -z $parentRepo ]] && die "missing PARENT_TEMPLATE"

# vars.
repo="$(basename "$PWD")" \
    || die "failed to get repository name"

# check if child is a new template.
isTemplate=false
[[ "$repo" == *"-template"* ]] && { isTemplate=true; }

# remove "things".
files=(
  ".github/workflows/dispatch.yml"
  ".github/workflows/template-cleanup.yml"
  "bin/dispatch.sh"
  "bin/template-cleanup.sh"
  "docs"
)
if [[ $isTemplate == true ]]; then
  files=(
    "docs"
  )
fi
for thing in "${files[@]}"; do
  echo "~~~ removing $thing"
  found=false
  [[ -d "$thing" ]] && { found=true; }
  [[ -f "$thing" ]] && { found=true; }
  [[ $found == false ]] \
    && die "failed to find $thing; does it exist?"
  rm -rf "$thing" \
    || die "failed to remove $thing"
done

# exit early, since the rest if child template specific.
[[ $isTemplate == false ]] && { exit 0; }

# find files to update with new child template name.
# shellcheck disable=SC2178
files=$(find . -type f \
  -not -path "$0" \
  -not -path "./.git/*" \
  -not -path "./docs/*" \
  -not -path "*README.md*" \
  -not -path "./.editorconfig")
# shellcheck disable=SC2128
for file in $files; do
  echo "~~~ updating $file"
  sed -i '' -e "s/$parentRepo/$repo/g" "$file" \
      || die "failed to sed update $file"
done
