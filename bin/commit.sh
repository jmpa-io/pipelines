#!/usr/bin/env bash

[[ -z $(git status --porcelain) ]] && { echo "no changes to commit; skipping"; exit 0; }
git config --global user.name 'GitHub Actions'
git config --global user.email '41898282+github-actions[bot]@users.noreply.github.com'
git add -A
git commit -m "Template cleanup" # want to trigger README.md build after.
git push origin HEAD:main