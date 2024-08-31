# Default PROJECT, if not given by another Makefile.
ifndef PROJECT
PROJECT=root-template
endif

# Services.
SERVICES =
# TODO: fill these out with services to deploy.

# Targets.
# TODO: fill these out with Make targets.

---: ## ---

# Includes the common Makefile.
# NOTE: this recursively goes back and finds the `.git` directory and assumes
# this is the root of the project. This could have issues when this assumtion
# is incorrect.
include $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/Makefile.common.mk


