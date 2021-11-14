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
currentBranch=$(git branch --show-current) \
  || die "failed to get current branch"

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
  || die "failed to fetch changes from $branch"
echo "##[endgroup]"

# check for any changes.
echo "##[group]Checking for any changes"
mapfile -t files < <(git diff --name-only "$currentBranch" "$remoteBranch") \
  || die "failed to get remote changed files list for $remoteBranch"
[[ ${#files[@]} -eq 0 ]] \
  && die "no changes found from $remoteBranch; skipping merge" 0
echo "##[endgroup]"

# merge.
echo "##[group]Merging changes from $remoteBranch to $currentBranch"
git merge "$remoteBranch" --allow-unrelated-histories
echo "##[endgroup]"

# reset unique files, since they'll be unique to each repository.
echo "##[group]Resetting files"
files=(
  "README.md"
  "img/logo.png"
)
for file in "${files[@]}"; do
  git checkout HEAD -- "$file" \
    || die "failed to reset $file"
done
echo "##[endgroup]"

# commit + push changes.
echo "##[group]Commit any extra changes"
git add -A
git commit -m "Update '$currentBranch' with latest changes from '$remoteBranch'"
echo "##[endgroup]"
