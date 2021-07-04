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
[[ $(git remote show $branch 2>/dev/null) ]] || {
  echo "##[group]Adding remote $branch"
  git remote add "$branch" "https://github.com/jmpa-oss/root-template.git" \
    || die "failed to add remote $branch"
  echo "##[endgroup]"
}

# fetch changes from parent.
echo "##[group]Fetching $branch changes"
git fetch "$branch" \
  || die "failed to fetch changes from "
echo "##[endgroup]"

# check for any changes.
echo "##[group]Checking for any changes"
[[ -z $(git status --porcelain) ]] && \
  die "no changes found from $remoteBranch; skipping merge"
echo "##[endgroup]"

# merge.
echo "##[group]Updating $branch with changes from $remoteBranch"
git merge "$remoteBranch" --allow-unrelated-histories \
  -m "update $branch with latest changes from $remoteBranch" \
  || die "failed to merge $remoteBranch changes to $branch"
echo "##[endgroup]"
