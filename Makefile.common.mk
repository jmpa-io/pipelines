
#
# This Makefile is generic across ALL repositories:
# https://github.com/jmpa-io/root-template/blob/main/Makefile.common.mk
#
# See the bottom for additional notes.
#

# The name of the project.
ifndef PROJECT
$(error PROJECT not defined, missing from Makefile?)
endif

# The default command executed when running `make`.
.DEFAULT_GOAL:=	help

#
# ┬  ┬┌─┐┬─┐┬┌─┐┌┐ ┬  ┌─┐┌─┐
# └┐┌┘├─┤├┬┘│├─┤├┴┐│  ├┤ └─┐
#  └┘ ┴ ┴┴└─┴┴ ┴└─┘┴─┘└─┘└─┘o
#

# The shell used for executing commands.
SHELL = /bin/sh

# The environment used when deploying; This can affect which config is used when deploying.
ENVIRONMENT ?= dev # The environment to deploy to.

# The git commit hash.
COMMIT = $(shell git describe --tags --always)

# The name of this repository.
REPO = $(shell basename $(shell git rev-parse --show-toplevel))

# The name of the GitHub organization commonly used.
ORG ?= jmpa-io

# The operating system this Makefile is being executed on.
OS := $(shell uname | tr '[:upper:]' '[:lower:]')

# The operating system used when building binaries.
BUILDING_OS ?= $(OS)

# A comma separated list of operating systems that can be used when building binaries.
SUPPORTED_OPERATING_SYSTEMS = linux,darwin

# Used for 'if' conditions in Make where a comma is needed.
COMMA := ,

# Linux specific variables.
ifeq ($(OS),linux)

	# Flags used when doing certain 'sed' commands.
	SED_FLAGS = -i

	# Command used to determine the size of a given file.
	FILE_SIZE = $(shell stat -c '%s' $<)

# Darwin specific variables.
else ifeq ($(OS),darwin)

	# Flags used when doing certain 'sed' commands.
	SED_FLAGS = -i ''

	# Command used to determine the size of a given file.
	FILE_SIZE = $(shell stat -f '%z' $<)

endif

# ---- Files & Directories ----

# A list of shell scripts under ALL paths (except submodules) in this repository.
SH_FILES := $(shell find . $(IGNORE_SUBMODULES) -name "*.sh" -type f 2>/dev/null)

# A list of Go files under ALL paths (except submodules) in this repository.
GO_FILES := $(shell find . $(IGNORE_SUBMODULES) -name "*.go" -type f 2>/dev/null)

# A list of Cloudformation templates under './cf' (except submodules) in this repository.
CF_FILES := $(shell find ./cf $(IGNORE_SUBMODULES) -name 'template.yml' -type f 2>/dev/null)

# A list of SAM templates under './cf' (except submodules) in this repository.
SAM_FILES := $(shell find ./cf $(IGNORE_SUBMODULES) -name 'template.yaml' -type f 2>/dev/null)

# A list of directories under './cf' (except submodules) housing Cloudformation templates.
CF_DIRS := $(shell find ./cf $(IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

# A list of workflows under '.github/workflows' (except submodules) in this repository.
WORKFLOW_FILES := $(shell find .github/workflows $(IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -name '*.yml' -type f 2>/dev/null)

# A list of Dockerfiles under ALL paths (except submodules) in this repository.
IMAGES := $(patsubst .,$(PROJECT),$(patsubst ./%,%,$(shell find . -name 'Dockerfile' -type f -exec dirname {} \; 2>/dev/null)))

# A list of directories under './cmd' that contain 'main.go'.
CMD_DIRS = $(shell find cmd/* -name main.go -maxdepth 1 -type f -exec dirname {} \; 2>/dev/null | awk -F/ '{$$1=""; sub(/^ /, ""); print $$0}')

# Adds 'cmd/' to each directory found under $(CMD_DIRS).
CMD_SOURCE = $(addprefix cmd/,$(CMD_DIRS))

# Adds 'binary-' to each directory found under $(CMD_DIRS).
BINARIES_TARGETS = $(addprefix binary-,$(CMD_DIRS))

# Adds 'dist/' to each directory found under $(CMD_DIRS).
BINARIES_OUTPUT_DIRECTORIES = $(addprefix dist/,$(CMD_DIRS))

# ---- Submodules ----

# The paths to any given submodules found in this repository.
SUBMODULES := $(shell git config --file $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/.gitmodules --get-regexp path | awk '{ print $$2 }')

# A space separated list of submodules to ignore when using 'find' commands in
# this Makefile.
IGNORE_SUBMODULES = $(foreach module,$(SUBMODULES),-not \( -path "./$(module)" -o -path "./$(module)/*" \))

# ---- AWS ----

# The region used when deploying a Cloudformation stack, or doing some things
# via the aws-cli, in the authed AWS account.
AWS_REGION ?= ap-southeast-2

# The Cloudformation stack name used when deploying a Cloudformation stack to
# the authed AWS account.
STACK_NAME = $(PROJECT)-$*

# The id of the authed AWS account.
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query 'Account' --output text)

# The default path to an AWS ECR repository for the authed AWS account.
ECR = $$(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# The name of a generic S3 bucket in the authed AWS account.
# TODO: should this be an AWS SSM Parameter Store path?
BUCKET ?= $(ORG)-artifacts

#
# ┌─┐┬ ┬┌┐┌┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
# ├┤ │ │││││   │ ││ ││││└─┐
# └  └─┘┘└┘└─┘ ┴ ┴└─┘┘└┘└─┘o
#

# Splits a string by '/' and retrieves the last element in the given array.
get_last_element = $(lastword $(subst /, ,$1))

#
# ┌┬┐┌─┐┌─┐┌─┐┌┐┌┌┬┐┌─┐┌┐┌┌─┐┬┌─┐┌─┐
#  ││├┤ ├─┘├┤ │││ ││├┤ ││││  │├┤ └─┐
# ─┴┘└─┘┴  └─┘┘└┘─┴┘└─┘┘└┘└─┘┴└─┘└─┘o
#

ifndef CI
EXECUTABLES ?= \
	awk \
	aws \
	cfn-lint \
	column \
	find \
	go \
	golangci-lint \
	grep \
	hadolint \
	sam \
	zip
MISSING := $(strip $(foreach bin,$(EXECUTABLES),$(if $(shell command -v $(bin) 2>/dev/null),,$(bin))))
$(if $(MISSING),$(error Please install: $(MISSING)))
endif

#
# ┬  ┬┌┐┌┌┬┐
# │  ││││ │
# ┴─┘┴┘└┘ ┴ o
#

.PHONY: lint
lint: ## ** Lints everything.
lint: \
	lint-sh \
	lint-go \
	lint-cf \
	lint-sam \
	lint-docker \
	lint-workflows

.PHONY: lint-sh
lint-sh: ## Lints shell files.
	@test -z "$(CI)" || echo "##[group]Linting sh."
ifeq ($(SH_FILES),)
	@echo "No *.sh files to lint."
else
	find . -type f -name "*.sh" -exec shellcheck '{}' \+ || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-go
lint-go: ## Lints Go files.
	@test -z "$(CI)" || echo "##[group]Linting Go."
ifeq ($(GO_FILES),)
	@echo "No *.go files to lint."
else
	golangci-lint run -v --allow-parallel-runners ./...
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-cf
lint-cf: ## Lints CF templates.
	@test -z "$(CI)" || echo "##[group]Linting Cloudformation."
ifeq ($(CF_FILES),)
	@echo "No ./cf/*/template.yml files to lint."
else
	find ./cf -type f -name 'template.yml' -exec sh -c 'cfn-lint -r $(AWS_REGION) -t "{}" && aws cloudformation validate-template --template-body file://{}' \;
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-sam
lint-sam: ## Lints SAM templates.
	@test -z "$(CI)" || echo "##[group]Linting sam."
ifeq ($(SAM_FILES),)
	@echo "No ./cf/*/template.yaml files to lint."
else
	find ./cf -type f -name 'template.yaml' -exec sam validate --region $(AWS_REGION)-t '{}' \; || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-docker
lint-docker: ## Lints Dockerfiles.
	@test -z "$(CI)" || echo "##[group]Linting Docker."
ifeq ($(DOCKER_FILES),)
	@echo "No Dockerfiles to lint."
else
	find . -type f -name 'Dockerfile' -exec hadolint '{}' \; || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-workflows
lint-workflows: ## Lints GitHub Action workflows.
	@test -z "$(CI)" || echo "##[group]Linting GitHub Action workflows."
ifeq ($(WORKFLOW_FILES),)
	@echo "No GitHub Action workflows to lint."
else
	find .github/workflows -mindepth 1 -maxdepth 1 -name '*.yml' -type f -exec actionlint '{}' \; || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

#
# ┌┬┐┌─┐┌─┐┌┬┐
#  │ ├┤ └─┐ │
#  ┴ └─┘└─┘ ┴ o
#

.PHONY: test
test: ## ** Tests everything.
test: \
	test-go

.PHONY: test-go
test-go: ## Runs Go tests.
test-go: dist/coverage.txt
dist/coverage.txt: dist
	@test -z "$(CI)" || echo "##[group]Unit tests."
ifeq ($(GO_FILES),)
	@echo "No *.go files to test or generate code-coverage."
else
	@go version
	CGO_ENABLED=1 go test -short -coverprofile=$@ \
    	-covermode=atomic -race -vet=off ./...
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: code-coverage
code-coverage: ## Generate a Go code coverage report, broken down by function.
code-coverage: dist/coverage.txt
	@if [[ -f $< ]]; then \
		test -z "$(CI)" || echo "##[group]Code coverage."; \
		go tool cover -func=$<; \
		test -z "$(CI)" || echo "##[endgroup]"; \
	fi

.PHONY: code-coverage-html
code-coverage-html: ## Generate a Go code HTML coverage report, rendered in the default browser.
code-coverage-html: dist/coverage.txt
	@if [[ -f $< ]]; then \
		go tool cover -html=$<; \
	fi

#
# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘o
#

.PHONY: binaries
binaries: ## ** Builds binaries only for the environment of the $(BUILDING_OS) operating system.
binaries: $(BINARIES_TARGETS)

.PHONY: binaries-all
binaries-all: ## ** Builds binaries for ALL supported operating systems under $(SUPPORTED_OPERATING_SYSTEMS).
	@for os in $(shell echo $(SUPPORTED_OPERATING_SYSTEMS) | tr ',' ' '); do \
		$(MAKE) --no-print-directory BUILDING_OS=$$os binaries; \
	done

# Creates the root output directory.
dist:
	@mkdir -p dist

# Creates the output directory, for a given service.
.SECONDARY: $(BINARIES_OUTPUT_DIRECTORIES)
dist/%: dist
	@mkdir -p dist/$*

# Builds a binary, for the given service, for the Linux environment.
define build_binary_linux
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
	go build --trimpath \
		-tags lambda.norpc \
		-ldflags "-w -s -X version.Version=$(COMMIT)" \
		-o dist/$*/$*-linux-amd64 ./cmd/$*
endef

# Builds a binary, for the given service, for the Darwin environment.
define build_binary_darwin
	CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 \
	go build --trimpath \
		-ldflags "-w -s -X version.Version=$(COMMIT)" \
		-o dist/$*/$*-darwin-arm64 ./cmd/$*
endef

# A wrapper for building a binary, for the given service, for the $(BUILDING_OS) environment.
define build_binary
	@echo "##[group]Building $* binary for $1."
	@go version
	$(call build_binary_$1)
	@test -z "$(CI)" || echo "##[endgroup]"
endef

binary-%: ## Builds a binary, for the given service, for the $(BUILDING_OS) environment.
binary-%: cmd/%/main.go dist/%
	$(call build_binary,$(BUILDING_OS))

#
# ┬  ┌─┐┌┬┐┌┐ ┌┬┐┌─┐
# │  ├─┤│││├┴┐ ││├─┤
# ┴─┘┴ ┴┴ ┴└─┘─┴┘┴ ┴ o
#

# Moves the bootstrap, for the given service, into the dist directory.
bootstrap-%: dist/% cmd/%/bootstrap
	@cp cmd/$*/bootstrap dist/$*/

invoke-%: ## Invokes the given service locally, using aws-sam-cli, if able.
invoke-%: cmd/%/local.sh binary-% bootstrap-%
	@$<

#
# ┌┬┐┌─┐┌─┐┬┌─┌─┐┬─┐
#  │││ ││  ├┴┐├┤ ├┬┘
# ─┴┘└─┘└─┘┴ ┴└─┘┴└─ o
#

.PHONY: images
images: ## ** Builds ALL docker images for each services.
images: $(foreach image,$(IMAGES),image-$(image))

define build_image
.PHONY: image-$1
## Builds the docker image for the given service.
image-$1: dist/$1-linux $(subst $(PROJECT),.,$1)/Dockerfile
	@test -z "$(CI)" || echo "##[group]Building $(strip $(call get_last_element,$(subst .,,$1))) image."
	docker build -t $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):$(COMMIT) -t $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):latest -f $(if $(filter $1,$(PROJECT)),./,$1/Dockerfile) .
	@test -z "$(CI)" || echo "##[endgroup]"
endef
$(foreach image,$(IMAGES),$(eval $(call build_image,$(image))))

.PHONY: push
push: ## ** Pushes ALL docker images to AWS ECR.
push: images-development
images-development: $(foreach image,$(IMAGES),push-$(image))

define push_image
.PHONY: push-$1
## Pushes the docker image for a given service to AWS ECR.
push-$1: image-$1
	@test -z "$(CI)" || echo "##[group]Pushing $(strip $(call get_last_element,$(subst .,,$1))) image."
	docker tag $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):$(COMMIT) $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
	docker tag $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):latest $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):latest
	docker push $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
	docker push $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):latest
	@test -z "$(CI)" || echo "##[endgroup]"
endef
$(foreach image,$(IMAGES),$(eval $(call push_image,$(image))))

.PHONY: pull
pull: ## ** Pulls ALL docker images for every service from AWS ECR.
pull: $(foreach image,$(IMAGES),pull-$(image))

define pull_image
.PHONY: pull-$1
## For the given service, pulls the associated docker image from AWS ECR.
pull-$1:
	docker pull $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
endef
$(foreach image,$(IMAGES),$(eval $(call pull_image,$(image))))

#
# ┌┬┐┌─┐┌─┐┬  ┌─┐┬ ┬
#  ││├┤ ├─┘│  │ │└┬┘
# ─┴┘└─┘┴  ┴─┘└─┘ ┴ o
#

# Sets PRIMARY_SERVICES to be SERVICES, so either can be used in ANY Makefile.
PRIMARY_SERVICES ?= $(SERVICES)

.PHONY: deploy $(PRIMARY_SERVICES) $(SECONDARY_SERVICES) $(TERTIARY_SERVICES) $(QUATERNARY_SERVICES) $(QUINARY_SERVICES)
deploy: ## ** Deploys the Cloudformation template for ALL services.
deploy: \
	$(PRIMARY_SERVICES) \
	$(SECONDARY_SERVICES) \
	$(TERTIARY_SERVICES) \
	$(QUATERNARY_SERVICES) \
	$(QUINARY_SERVICES)

deploy-%: ## Deploys the Cloudformation template for the given service.
deploy-%: cf/%/package.yml
ifndef ENVIRONMENT
	$(error ENVIRONMENT not defined; please populate it before deploying)
else
	@test -z "$(CI)" || echo "##[group]Deploying $*."
	aws cloudformation deploy \
		--region $(AWS_REGION) \
		--template-file $< \
		$(shell [[ $(FILE_SIZE) -ge 51200 ]] && echo "--s3-bucket $(BUCKET)") \
		--stack-name $(STACK_NAME) \
		--tags repository=$(REPO) project=$(PROJECT) component=$* revision=$(COMMIT) \
		$(if $(ADDITIONAL_STACK_TAGS),$(ADDITIONAL_STACK_TAGS),) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
		--parameter-overrides Component=$* Revision=$(COMMIT) Environment=$(ENVIRONMENT) \
		$(if $(wildcard cf/.params/$(ENVIRONMENT).json),$(shell jq -r 'map("\(.ParameterKey)=\(.ParameterValue)") | join(" ")' ./cf/.params/$(ENVIRONMENT).json),) \
		$(if $(ADDITIONAL_PARAMETER_OVERRIDES),$(ADDITIONAL_PARAMETER_OVERRIDES),) \
		--no-fail-on-empty-changeset
	@test -z "$(CI)" || echo "##[endgroup]"
endif

cf/%/package.yml: ## Packages the Cloudformation template for the given service.
cf/%/package.yml: cf/%/template.yml
ifndef ENVIRONMENT
	$(error ENVIRONMENT not defined; please populate it before deploying)
else
	@test -z "$(CI)" || echo "##[group]Packaging $*."
	aws cloudformation package \
		--region $(AWS_REGION) \
		--template-file $< \
		--output-template-file $@ \
		--s3-prefix $(PROJECT) \
		--s3-bucket $(BUCKET)
	@test -z "$(CI)" || echo "##[endgroup]"
endif

#
# ┌┬┐┬┌─┐┌─┐
# ││││└─┐│
# ┴ ┴┴└─┘└─┘ o
#

.PHONY: update-template
update-template: ## Pulls changes from the pre-defined template into this repository.
	git fetch template
	git merge template/main --allow-unrelated-histories

.PHONY: clean
clean: ## Removes generated files & folders, resetting this repository back to its initial clone state.
	@test -z "$(CI)" || echo "##[group]Cleaning up."
	@rm -f coverage.* traces.*
	@rm -rf dist
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: help
help: ## Prints this help page.
	@echo "Available targets:"
	@awk_script='\
		/^[a-zA-Z\-\\_0-9%\/$$]+:/ { \
			target = $$1; \
			gsub("\\$$1", "%", target); \
			nb = sub(/^## /, "", helpMsg); \
			if (nb == 0) { \
				helpMsg = $$0; \
				nb = sub(/^[^:]*:.* ## /, "", helpMsg); \
			} \
			if (nb) print "\033[33m" target "\033[0m" helpMsg; \
		} { helpMsg = $$0 } \
	'; \
	awk "$$awk_script" $(MAKEFILE_LIST) | column -ts:

#
# ┬  ┬┌─┐┌┬┐
# │  │└─┐ │
# ┴─┘┴└─┘ ┴ o
#

.PHONY: list-project
list-project: # Lists the project name used within the Makefile.
	@echo $(PROJECT)

.PHONY: list-org
list-org: # Lists the GitHub organization used within the Makefile.
	@echo $(ORG)

.PHONY: list-sh
list-sh: # Lists ALL shell scripts under the current directory.
	@echo $(SH_FILES)

.PHONY: list-go
list-go: # Lists ALL Go files under the current directory.
	@echo $(GO_FILES)

.PHONY: list-cf
list-cf: # Lists ALL dirs under ./cf.
	@echo $(CF_DIRS)

.PHONY: list-cmd
list-cmd: # Lists ALL dirs under ./cmd.
	@echo $(CMD_DIRS)

.PHONY: list-workflows
list-workflows: # Lists ALL workflows under the '.github/workflows' directory.
	@echo $(WORKFLOW_FILES)

.PHONY: list-binaries
list-binaries: # Lists ALL binary targets and their output directories.
	@echo $(BINARIES_TARGETS)
	@echo $(BINARIES_OUTPUT_DIRECTORIES)

.PHONY: list-images
list-images: # Lists ALL docker images for every service.
	@echo $(IMAGES)

.PHONY: list-deploy
list-deploy: # Lists ALL services to deploy.
	@echo $(PRIMARY_SERVICES)
	@echo $(SECONDARY_SERVICES)
	@echo $(TERTIARY_SERVICES)
	@echo $(QUATERNARY_SERVICES)
	@echo $(QUINARY_SERVICES)

.PHONY: list-deploy
list-submodules: # Lists ALL submodules.
	@echo $(SUBMODULES)

