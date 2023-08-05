<!-- markdownlint-disable MD041 MD010 -->
[![README.yml](https://github.com/jmpa-io/root-template/actions/workflows/README.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/README.yml)
[![cicd.yml](https://github.com/jmpa-io/root-template/actions/workflows/cicd.yml/badge.svg)](https://github.com/jmpa-io/root-template/actions/workflows/cicd.yml)

# `root-template`

```diff
+ 🧱 A template used to store any generic files used by all other repositories in
+ this org. Used in conjunction with https://github.com/jmpa-io/depot.
```

## 🧠 How do I use this template?

1. Using a <kbd>terminal</kbd>, download the child repository locally.

2. From the root of that child repository, run:
```bash
git remote add template https://github.com/jmpa-io/root-template.git
git fetch template
git merge template/main --allow-unrelated-histories
# then fix any merge conflicts as required %HOW_TO_USE_TEMPLATE% 'git push' when ready.
```
