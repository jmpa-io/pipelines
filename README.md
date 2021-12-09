[![README.md](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml/badge.svg)](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml)

<p align="center">
	<img src="img/logo.png">
</p>

# root-template

```diff
+ %DESCRIPTION%
```

## Workflows

workflow|description
---|---
[README.md](.github/workflows/README.md.yml)|Updates the README.md with new changes.


## How do I use this template.

1. Using a <kdb>terminal</kdb>, `cd` to a repository locally you want to add this template to.

2. Run:
```bash
git remote add template https://github.com/jmpa-oss/repo-template.git
git fetch main
git merge template/main
# then fix any merge conflicts as required.
git push
```
