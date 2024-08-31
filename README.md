<!-- markdownlint-disable MD041 MD010 -->
[![root-template](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/README.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/README.yml)
[![root-template](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/cicd.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/cicd.yml)
[![root-template](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/dependabot-automerge.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/.github/workflows/dependabot-automerge.yml)

<p align="center">
  <img src="docs/logo.png">
</p>

# `root-template`

```diff
+ 🧱 A template used to store any generic files used by all other repositories
+ in in this org. Used in conjunction with https://github.com/jmpa-io/pipelines.
```

## `Scripts`

👉 Here is a list of scripts in this repository:

Script|Description
:---|:---
[bin/README.sh](bin/README.sh) | Generates a README.md, using a README.md template.
[bin/description.sh](bin/description.sh) | This is a test script, and should be ignored. This line should also be included.

## 🧠 How do I use this template?

1. Using a <kbd>terminal</kbd>, download the child repository locally.

2. From the root of that child repository, run:
```bash
git remote add template https://github.com/root-template.git
git fetch template
git merge template/main --allow-unrelated-histories
# then fix any merge conflicts as required & 'git push' when ready.
```
