# Default PROJECT, if not given by another Makefile.

ifeq ($(PROJECT),)
PROJECT=pipelines
endif

# AWS_ACCOUNT_ID := $(shell aws sts get-caller-identity --query 'Account' --output text)
# AWS_REGION := $(shell aws configure get region)
# AWS_RUNNER_ROLE_NAME := $(shell aws ssm get-parameter --name '/oidc/iam-role-name' --query 'Parameter.Value' --output text --with-decryption)
#
---: ## ---

dispatch: ## Dispatches an event to ALL the repositories in the $ORG; This will trigger the CI/CD workflow to run per repository.
	./bin/00-dispatch.sh

# create-secrets: ## Creates the .secrets file locally.
# 	@{ \
# 		echo "AWS_ACCOUNT_ID=$(AWS_ACCOUNT_ID)"; \
# 		echo "AWS_REGION=$(AWS_REGION)"; \
# 		echo "AWS_RUNNER_ROLE_NAME=$(AWS_RUNNER_ROLE_NAME)"; \
# 	} > .secrets
#
# run-workflows: ## Runs ALL GitHub Action workflows locally.
# run-workflows: create-secrets
# 	act -W .github/workflows/.cicd.yml
#
# Includes the common Makefile.
# NOTE: this recursively goes back and finds the `.git` directory and assumes
# this is the root of the project. This could have issues when this assumtion
# is incorrect.
include $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/Makefile.common.mk

