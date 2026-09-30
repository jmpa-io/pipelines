# Default PROJECT, if not given by another Makefile.
ifeq ($(PROJECT),)
PROJECT=pipelines
endif

---: ## ---

dispatch: ## Dispatches an event to ALL the repositories in the $ORG; This will trigger the CI/CD workflow to run per repository.
	./bin/00-dispatch.sh $(ORG)

sync: ## Syncs the dist directory to the S3 bucket for this repository.
	./bin/40-sync.sh

PHONY += dispatch sync

# Includes the common Makefile.
# NOTE: this recursively goes back and finds the `.git` directory and assumes
# this is the root of the project. This could have issues when this assumtion
# is incorrect.
include $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/Makefile.common.mk

