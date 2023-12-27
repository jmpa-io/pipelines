# default PROJECT, if not given by another Makefile.
ifndef PROJECT
PROJECT=roots
endif

---: ## ---

# includes the common Makefile.
# PLEASE NOTE: this recursively goes back and finds the `.git` directory and
# assumes this is the root of the project.
include $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/Makefile.common.mk
