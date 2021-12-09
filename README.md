<p align="center">
	<img src="img/logo.png">
</p>

[![README.md](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml/badge.svg)](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml)

# root-template

```diff
+ The root template, used for other projects / other templates.
```

## Workflows

workflow|description
---|---
[README.md](.github/workflows/README.md.yml)|Updates the README.md with new changes.


## How do I use this template?

1. Using a <kbd>terminal</kbd>, download the child repository locally.

2. From the root of that child repository, run:
```bash
git remote add template https://github.com/jmpa-oss/repo-template.git
git fetch main
git merge template/main
# then fix any merge conflicts as required & 'git push' when ready.
```
