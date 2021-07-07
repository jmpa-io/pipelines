#!/usr/bin/env bash
# updates all hard-coded name references in a template, so it
# can be used a template itself.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check deps.
deps=(find basename sed)
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

# check if this is a template repository.
[[ "$repo" == *"-template"* ]] \
  || die "'$repo' is not a template repository; skipping" 0

# read PARENT_TEMPLATE.
# NOTE: doing this, since it's not safe to modify
#       a bash script while it's running.
parentRepo="${PARENT_TEMPLATE}"
[[ -z $parentRepo ]] && die "missing PARENT_TEMPLATE"

# shellcheck disable=SC2178
files=$(find . -type f \
  -not -path "$0" \
  -not -path "./.git/*" \
  -not -path "./docs/*" \
  -not -path "*README.md*" \
  -not -path "./.github/workflows/update.yml" \
  -not -path "./.editorconfig")
# shellcheck disable=SC2128
for file in $files; do
  echo "##[group]Updating $file"
  i="-i ''"
  [[ -z "$GITHUB_ACTIONS" ]] || { i="-i''"; }
  sed "$i" -e "s/$parentRepo/$repo/g" "$file" \
    || die "failed to sed update $file"
  echo "##[endgroup]"
done
