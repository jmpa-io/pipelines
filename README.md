[![cicd-local](https://github.com/jmpa-io/depot/actions/workflows/cicd-local.yml/badge.svg)](https://github.com/jmpa-io/depot/actions/workflows/cicd-local.yml)
[![cicd](https://github.com/jmpa-io/depot/actions/workflows/cicd.yml/badge.svg)](https://github.com/jmpa-io/depot/actions/workflows/cicd.yml)
[![README-local](https://github.com/jmpa-io/depot/actions/workflows/README-local.yml/badge.svg)](https://github.com/jmpa-io/depot/actions/workflows/README-local.yml)
[![README](https://github.com/jmpa-io/depot/actions/workflows/README.yml/badge.svg)](https://github.com/jmpa-io/depot/actions/workflows/README.yml)

<div align="center">

# `depot`

</div>

```diff
+ 📦 A repository to store anything used across all projects in this org (eg. generic scripts, cloudformation templates, github action workflows). Used in conjuntion with the root-template!
```

## Workflows

workflow|description
---|---
[cicd-local](.github/workflows/cicd-local.yml)|Name: Run CI/CD.uses: ./.github/workflows/cicd.ymlsecrets:github-token: ${{ secrets.ADMIN_GITHUB_TOKEN }}slack-webhook: ${{ secrets.SLACK_GITHUB_WEBHOOK_URL }}
[cicd](.github/workflows/cicd.yml)|Run CI/CD.
[README-local](.github/workflows/README-local.yml)|Updating README.md, if there are any changes.uses: ./.github/workflows/README.ymlsecrets:github-token: ${{ secrets.ADMIN_GITHUB_TOKEN }}slack-webhook: ${{ secrets.SLACK_GITHUB_WEBHOOK_URL }}
[README](.github/workflows/README.yml)|Updating README.md, if there are any changes.

