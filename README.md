[![README.md](https://github.com/jmpa-oss/template/actions/workflows/README.md.yml/badge.svg)](https://github.com/jmpa-oss/template/actions/workflows/README.md.yml)
[![dispatch](https://github.com/jmpa-oss/template/actions/workflows/dispatch.yml/badge.svg)](https://github.com/jmpa-oss/template/actions/workflows/dispatch.yml)
[![template-cleanup](https://github.com/jmpa-oss/template/actions/workflows/template-cleanup.yml/badge.svg)](https://github.com/jmpa-oss/template/actions/workflows/template-cleanup.yml)
[![update](https://github.com/jmpa-oss/template/actions/workflows/update.yml/badge.svg)](https://github.com/jmpa-oss/template/actions/workflows/update.yml)

# template

```diff
+ The root template, used for other projects / other templates.
```

## workflows

workflow|description
---|---
[README.md](.github/workflows/README.md.yml)|Updates the README.md with new changes.
[dispatch](.github/workflows/dispatch.yml)|Pushes repository_dispatch events out to repositories built from this template.
[template-cleanup](.github/workflows/template-cleanup.yml)|Cleans up the repository when a child is first created; triggers from the first commit to the repository.
[update](.github/workflows/update.yml)|Updates repository with changes from parent template.

