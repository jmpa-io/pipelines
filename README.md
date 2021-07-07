[![dispatch](https://github.com/jmpa-oss/root-template/actions/workflows/dispatch.yml/badge.svg)](https://github.com/jmpa-oss/root-template/actions/workflows/dispatch.yml)
[![README.md](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml/badge.svg)](https://github.com/jmpa-oss/root-template/actions/workflows/README.md.yml)

<p align="center">
	<img src="docs/logo.png">
</p>

# root-template

```diff
+ The root template, used for other projects / other templates.
```

## Workflows

workflow|description
---|---
[dispatch](.github/workflows/dispatch.yml)|Pushes repository_dispatch events out to repositories built from this template.
[README.md](.github/workflows/README.md.yml)|Updates the README.md with new changes.
[template-cleanup](.github/workflows/template-cleanup.yml)|Cleans up the repository when a child is first created; triggers from the first commit to the repository.
[update](.github/workflows/update.yml)|Updates repository with changes from parent template.

