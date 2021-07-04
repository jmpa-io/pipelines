#!/usr/bin/env bash
# updates child repository built from the parent template
# with the latest changes.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# check remote has been setup already.
[[ $(git remote show template 2>/dev/null) ]] || {
  git remote add template "https://github.com/jmpa-oss/root-template.git" \
    || die "failed to add remote template"
}

# fetch template changes.
git fetch template \
  || die "failed to fetch template changes"

# setup branches.
remotebranch="template/main"
branch=$(git branch --show-current) \
  || die "failed to get current checked out branch"

# check for any changes.
mapfile -t files < <(git diff --name-only "$branch" "$remotebranch") \
  || die "failed to get remote changed files list for $remotebranch"
[[ ${#files[@]} -eq 0 ]] \
  && die "no files found to update for $remotebranch, skipping merge to $branch" 0

# merge changes.
# TODO if this fails, should it make a PR in GitHub as a backup?
echo "##[group]Merging $remotebranch changes to $branch"
git merge "$remotebranch" --allow-unrelated-histories \
  -m "update $branch with latest changes from $remotebranch" \
  || die "failed to merge $remotebranch changes to $branch"
echo "##[endgroup]"
