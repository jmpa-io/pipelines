<!-- markdownlint-disable MD041 MD010 -->

<p align="centre">
    <img src="docs/logo.png">
</p>

## `pipelines`

```diff
+ 🌱 A collection of org-wide pipelines used by other repositories in this org.
```

<a href="LICENSE" target="_blank"><img src="https://img.shields.io/github/license/jmpa-io/pipelines.svg" alt="GitHub License"></a>
[![CI/CD](https://github.com/jmpa-io/templates/actions/workflows/.github/workflows/cicd.yml/badge.svg)](https://github.com/jmpa-io/templates/actions/workflows/.github/workflows/cicd.yml)
[![Automerge](https://github.com/jmpa-io/templates/actions/workflows/.github/workflows/dependabot-automerge.yml/badge.svg)](https://github.com/jmpa-io/templates/actions/workflows/.github/workflows/dependabot-automerge.yml)

## `Usage`

Below is an example of how to use a pipeline (aka. `workflow`) from this repository:

```yaml
jobs:
    my-job:
        uses: jmpa-io/pipelines/.github/workflows/<workflow>.yml@main
        with:
            // add any variables that the workflow may require.
        secrets:
            // add any secrets that the workflow may require.
```
