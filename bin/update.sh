#!/usr/bin/env bash
# updates child repository built from the parent template
# with the latest changes.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# vars.
branch="template"
remoteBranch="$branch/main"

# add template as parent, if not found.
if [[ $(git remote show $branch 2>/dev/null) ]]; then
  git remote add "$branch" "https://github.com/jmpa-oss/root-template.git" \
    || die "failed to add remote $branch"
fi

# fetch changes from parent.
git fetch "$branch" \
  || die "failed to fetch changes from "

# check for any changes.
[[ -z $(git status --porcelain) ]] && \
  die "no changes found from $remoteBranch; skipping merge"

# merge.
git merge "$remoteBranch" --allow-unrelated-histories \
  -m "update $branch with latest changes from $remoteBranch" \
  || die "failed to merge $remoteBranch changes to $branch"
