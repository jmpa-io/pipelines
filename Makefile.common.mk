#
# This Makefile is generic across all repositories:
# https://github.com/jmpa-io/root-template/blob/main/Makefile.common.mk
#

# Check project variables are given.
ifndef PROJECT
$(error PROJECT not defined, missing Makefile?)
endif

# Vars.
SHELL			= /bin/sh # The shell used when make runs `shell`.
ENVIRONMENT		?= dev # The environment being deployed; affects what type of resources are used when deploying.
COMMIT			= $(shell git describe --tags --always) # The git commit associated with the repository.
REPO			= $(shell basename $$PWD) # The name of the git repository this was deployed from.
# ---
CMD_SOURCE		= $(shell find cmd/$* -type f 2>/dev/null) # The source for a command.
SH_FILES		:= $(shell find . -name "*.sh" -type f) # A list of ALL sh files in the repository.
GO_FILES 		:= $(shell find . -name "*.go" -type f) # A list of ALL Go files in the repository.
BINARIES 		= $(patsubst %,dist/%,$(shell find cmd/* -maxdepth 0 -type d -exec basename {} \; 2>/dev/null)) # A list of ALL binaries in the repository.
BINARIES_LINUX	= $(patsubst %,%-linux,$(BINARIES)) # A list of ALL linux binaries in the repository.
# ---
AWS_REGION		?= ap-southeast-2 # The region to use when doing things in AWS.
STACK_NAME		= $(PROJECT)-$* # The format of the generated name for Cloudformation stacks in AWS.

# Check deps.
EXECUTABLES ?= awk column grep go golangci-lint find aws zip
MISSING := $(strip $(foreach bin,$(EXECUTABLES),$(if $(shell command -v $(bin) 2>/dev/null),,$(bin))))
$(if $(MISSING),$(error Please install: $(MISSING); $(PATH)))

# The default command executed when running `make`.
.DEFAULT_GOAL:=	help

# ┬  ┬ ┌┐┌┌┬┐
# │  │ │││ │
# ┴─┘┴ ┘└┘ ┴

.PHONY: lint
lint: lint-sh lint-go ## ** Lints everything.

.PHONY: lint-sh
lint-sh: ## Lints shell files.
	@test -z "$(CI)" || echo "##[group]Linting sh."
ifeq ($(strip $(SH_FILES)),)
	@echo "No *.sh files to lint."
else
	find . -name "*.sh" -exec shellcheck '{}' \+
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-go
lint-go: ## Lints Go files.
	@test -z "$(CI)" || echo "##[group]Linting Go."
ifeq ($(strip $(GO_FILES)),)
	@echo "No *.go files to lint."
else
	@golangci-lint run -v --allow-parallel-runners
endif
	@test -z "$(CI)" || echo "##[endgroup]"

# ┌┬┐┌─┐┌─┐┌┬┐
#  │ ├┤ └─┐ │
#  ┴ └─┘└─┘ ┴

.PHONY: test
test: test-go ## ** Tests everything.

.PHONY: test-go
test-go: dist ## Tests Go + generates coverage report.
	@test -z "$(CI)" || echo "##[group]Unit tests."
ifeq ($(strip $(GO_FILES)),)
	@echo "No *.go files to test."
else
	@go version
	@go test -short -coverprofile=dist/coverage.txt -covermode=atomic -race -vet=off ./... \
		&& go tool cover -func=dist/coverage.txt
endif
	@test -z "$(CI)" || echo "##[endgroup]"

# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘

.PHONY: binaries list-binaries
binaries: $(BINARIES) ## ** Builds ALL binaries.
list-binaries: ## Lists ALL binaries.
	@echo $(BINARIES)
list-binaries-linux: ## Lists ALL Linux binaries.
	@echo $(BINARIES_LINUX)

dist: ; mkdir dist # Creates the dist directory, if missing.

## Builds the binary for the given service (for the local machine platform - GOOS).
binary-%: dist/%
dist/%: $(CMD_SOURCE)
	@test -z "$(CI)" || echo "##[group]Building $@"
	@go version
	@go build --trimpath -ldflags "-w -s \
		    -X version.Version=$(COMMIT)" \
		    -o $@ ./cmd/$*
	@test -z "$(CI)" || echo "##[endgroup]"

## Builds the binary for the given service (for Linux).
binary-%-linux: dist/%-linux
dist/%-linux: $(CMD_SOURCE)
	@test -z "$(CI)" || echo "##[group]Building $@"
	@go version
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build --trimpath -ldflags "-w -s \
		    -X version.Version=$(COMMIT)" \
		    -o $@ ./cmd/$*
	@test -z "$(CI)" || echo "##[endgroup]"

## Zips the given service.
dist/%.zip: dist/%-linux
	@zip -rjDm $@ dist/$*-linux

# ┌┬┐┌─┐┌─┐┬  ┌─┐┬ ┬
#  ││├┤ ├─┘│  │ │└┬┘
# ─┴┘└─┘┴  ┴─┘└─┘ ┴

.PHONY: deploy $(COMPONENT)
deploy: $(SERVICES) ## ** Deploys the Cloudformation template for ALL services.

.PHONY: list-deploy
list-deploy: ## Lists ALL services to deploy.
	@echo $(SERVICES)

## Deploys the Cloudformation template for the given service.
deploy-%: cf/%/package.yml
	@test -z "$(CI)" || echo "##[group]Deploying $*."
	aws cloudformation deploy \
		--region $(AWS_REGION) \
		--template-file $< \
		--stack-name $(STACK_NAME) \
		--tags repo=$(REPO) project=$(PROJECT) component=$* \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameter-override Component=$* Revision=$(COMMIT) Environment=$(ENVIRONMENT) \
		--no-fail-on-empty-changeset
	@test -z "$(CI)" || echo "##[endgroup]"

## Packages the Cloudformation template for the given service.
cf/%/package.yml: cf/%/template.yml
	@test -z "$(CI)" || echo "##[group]Packaging $*."
	aws cloudformation package \
		--region $(AWS_REGION) \
		--template-file $< \
		--output-template-file $@ \
		--s3-prefix $(PROJECT) \
		--s3-bucket kepler-deployment-$(ENVIRONMENT)
	@test -z "$(CI)" || echo "##[endgroup]"

# ┌┬┐┬┌─┐┌─┐
# ││││└─┐│
# ┴ ┴┴└─┘└─┘

.PHONY: update-template
update-template: ## Pulls changes from obs-template into this repository.
	git fetch template
	git merge template/master --allow-unrelated-histories

.PHONY: clean
clean: ## Removes generated files and folders, resetting this repository back to its initial clone state.
	@test -z "$(CI)" || echo "##[group]Cleaning up."
	@rm -f coverage.* traces.*
	@rm -rf dist
	@test -z "$(CI)" || echo "##[endgroup]"


.PHONY: help
help: ## Prints this help page.
	@echo "Available targets:"
	@awk '/^[a-zA-Z\-\_0-9%\/]+:/ { \
		nb = sub( /^## /, "", helpMsg ); \
		if(nb == 0) { helpMsg = $$0; nb = sub( /^[^:]*:.* ## /, "", helpMsg ); } \
		if (nb) print "\033[35m" $$1 "\033[0m" helpMsg; \
	} { helpMsg = $$0 }' $(MAKEFILE_LIST) \
	| column -ts:
