#!/usr/bin/env bash
# setups up the update.sh script, so the first
# commit doesn't require manual merging.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# add template as parent.
git remote add template "https://github.com/jmpa-oss/root-template.git" \
  || die "failed to add remote template"
