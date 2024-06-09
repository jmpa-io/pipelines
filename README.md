<!-- markdownlint-disable MD041 MD010 -->
[![.README.yml](https://github.com/jmpa-io/pipelines/actions/workflows/.README.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/.README.yml)
[![.cicd.yml](https://github.com/jmpa-io/pipelines/actions/workflows/.cicd.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/.cicd.yml)
[![00-README.yml](https://github.com/jmpa-io/pipelines/actions/workflows/00-README.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/00-README.yml)
[![00-dependabot-automerge.yml](https://github.com/jmpa-io/pipelines/actions/workflows/00-dependabot-automerge.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/00-dependabot-automerge.yml)
[![10-lint.yml](https://github.com/jmpa-io/pipelines/actions/workflows/10-lint.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/10-lint.yml)
[![20-test.yml](https://github.com/jmpa-io/pipelines/actions/workflows/20-test.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/20-test.yml)
[![30-build-binaries.yml](https://github.com/jmpa-io/pipelines/actions/workflows/30-build-binaries.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/30-build-binaries.yml)
[![35-build-and-push-images-to-ecr.yml](https://github.com/jmpa-io/pipelines/actions/workflows/35-build-and-push-images-to-ecr.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/35-build-and-push-images-to-ecr.yml)
[![40-deploy.yml](https://github.com/jmpa-io/pipelines/actions/workflows/40-deploy.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/40-deploy.yml)
[![45-upload-website-to-s3.yml](https://github.com/jmpa-io/pipelines/actions/workflows/45-upload-website-to-s3.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/45-upload-website-to-s3.yml)
[![80-dispatch.yml](https://github.com/jmpa-io/pipelines/actions/workflows/80-dispatch.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/80-dispatch.yml)
[![99-post-to-slack.yml](https://github.com/jmpa-io/pipelines/actions/workflows/99-post-to-slack.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/99-post-to-slack.yml)
[![TODO/deploy-redirect.yml](https://github.com/jmpa-io/pipelines/actions/workflows/TODO/deploy-redirect.yml/badge.svg)](https://github.com/jmpa-io/pipelines/actions/workflows/TODO/deploy-redirect.yml)

<p align="center">
  <img src="docs/logo.png"/>
</p>

# `pipelines`

```diff
+ 🌱 A monorepo used to store org-wide resources used by other repositories in
+ this org, such as pipelines, scripts, mechanisms to deploy, and templates. Used
+ in conjunction with https://github.com/jmpa-io/root-template.
```

## `scripts`

👉 Here is a list of scripts in this repository:

Script|Description
:---|:---
[bin/00-dispatch.sh](bin/00-dispatch.sh) | Trigger a repository_dispatch event in ALL repositories in a given GitHub org.
[bin/30-deploy.sh](bin/30-deploy.sh) | Deploys the given cloudformation template to the authed AWS account.
[bin/40-sync.sh](bin/40-sync.sh) | Uploads the dist directory to an expected S3 bucket in the authed AWS account.
[bin/clear-action-runs.sh](bin/clear-action-runs.sh) | Clears all GitHub Action runs for a given GitHub repository.
[bin/commit.sh](bin/commit.sh) | As the GitHub Actions user, this script commits back to the git repository it is executed in.
[bin/dispatch.sh](bin/dispatch.sh) | Trigger a repository_dispatch event in ALL repositories in a given GitHub org.
[bin/invalidate-cloudfront-distribution.sh](bin/invalidate-cloudfront-distribution.sh) | Invalidates files in the CloudFront cache, for the repostitory this script is execututed in - best to be run in a website repository.
[bin/list-repository-topics.sh](bin/list-repository-topics.sh) | Lists ALL topics for a given GitHub repository in a given GitHub org.

