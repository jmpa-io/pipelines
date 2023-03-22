#!/usr/bin/env bash
# as the GitHub Actions user, this script commits back to the git repository it is executed in.
# PLEASE NOTE: this script is only intended to be run in a GitHub Action workflow.

# funcs.
die() { echo "$1" >&2; exit "${2:-1}"; }

# check pwd.
[[ ! -d .git ]] \
  && die "must be run from repository root directory"

# anything to commit?
[[ -z $(git status --porcelain) ]] \
  && { echo "no changes to commit; skipping"; exit 0; }

# vars.
name="GitHub Actions"
email="'41898282+github-actions[bot]@users.noreply.github.com"

echo "##[group]What was modified?"
git diff --name-only; echo -e "\n\n"
echo "##[endgroup]"

echo "##[group]Commiting changes."
git config --global user.name "$name"
git config --global user.email "$email"
git add -A
git commit -m "[skip ci] Updated README.md"
git push origin HEAD:"$GITHUB_REF"
echo "##[endgroup]"
