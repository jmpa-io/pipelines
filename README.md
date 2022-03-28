<!-- markdownlint-disable MD041 MD010 -->
[![root-template](https://github.com/jmpa-io/root-template/actions/workflows/cicd.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/cicd.yml)
[![root-template](https://github.com/jmpa-io/root-template/actions/workflows/README.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/README.yml)

# `root-template`

```diff
+ 🌱 The root template used by all other repositories in this org.
```

## Scripts

script|description
---|---
[bin/00-clear-runs.sh](bin/00-clear-runs.sh) | Clears all GitHub Action runs for a given GitHub repository.
[bin/00-commit.sh](bin/00-commit.sh) | Commits back to the repository the script is run in, as the GitHub Actions user.
[bin/00-README.sh](bin/00-README.sh) | Generates a README.md, using a found README.md template.
[bin/00-repo-topics.sh](bin/00-repo-topics.sh) | Lists all topics for a given GitHub repository in a given org.
[bin/10-lint.sh](bin/10-lint.sh) | Lints everything!
[bin/20-test.sh](bin/20-test.sh) | Tests everything!
[bin/30-deploy.sh](bin/30-deploy.sh) | Deploys a cloudformation stack, based on the given template.


## How do I use this template?

1. Using a <kbd>terminal</kbd>, download the child repository locally.

2. From the root of that child repository, run:
```bash
git remote add template https://github.com/jmpa-io/root-template.git
git fetch template
git merge template/main --allow-unrelated-histories
# then fix any merge conflicts as required & 'git push' when ready.
```
