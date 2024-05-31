#
# This Makefile is generic across all repositories:
# https://github.com/jmpa-io/root-template/blob/main/Makefile.common.mk
#
# See the bottom for additional notes.
#

# Check project variables are given.
ifndef PROJECT
$(error PROJECT not defined, missing from Makefile?)
endif

# Variables.
SHELL          					= /bin/sh # The shell to use for executing commands.
ENVIRONMENT     				?= dev # The environment to deploy to.
COMMIT          				= $(shell git describe --tags --always) # The git commit hash.
REPO            				= $(shell basename $(shell git rev-parse --show-toplevel)) # The name of the repository.
COMMA							:= , # Used for if conditions in Make where a comma is needed.
OS 								:= $(shell uname | tr '[:upper:]' '[:lower:]') # The operating system the Makefile is being executed on.
BUILDING_OS 					?= $(OS) # The operating system used when building binaries.
SUPPORTED_OPERATING_SYSTEMS 	= linux,darwin # A list of operating systems that can be used when building binaries.

# Setup OS specific variables.
ifeq ($(OS),linux)
	SED_FLAGS 	= -i
	FILE_SIZE 	= $(shell stat -c '%s' $<)
else ifeq ($(OS),darwin)
	SED_FLAGS 	= -i ''
	FILE_SIZE	= $(shell stat -f '%z' $<)
endif

# Files + Directories.
SH_FILES    := $(shell find . $(IGNORE_SUBMODULES) -name "*.sh" -type f 2>/dev/null)
GO_FILES	:= $(shell find . $(IGNORE_SUBMODULES) -name "*.go" -type f 2>/dev/null)
CF_FILES    := $(shell find ./cf $(IGNORE_SUBMODULES) -name 'template.yml' -type f 2>/dev/null)
SAM_FILES	:= $(shell find ./cf $(IGNORE_SUBMODULES) -name 'template.yaml' -type f 2>/dev/null)
CF_DIRS     := $(shell find ./cf $(IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
CMD_DIRS    := $(shell find ./cmd $(IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
IMAGES      := $(patsubst .,$(PROJECT),$(patsubst ./%,%,$(shell find . -name 'Dockerfile' -type f -exec dirname {} \; 2>/dev/null)))

# Submodules.
SUBMODULES 			:= $(shell git config --file $(shell while [[ ! -d .git ]]; do cd ..; done; pwd)/.gitmodules --get-regexp path | awk '{ print $$2 }')
IGNORE_SUBMODULES 	= $(foreach module,$(SUBMODULES),-not \( -path "./$(module)" -o -path "./$(module)/*" \))

# Binaries.
CMD_DIRS 					= $(shell find cmd/* -name main.go -maxdepth 1 -type f -exec dirname {} \; 2>/dev/null | awk -F/ '{$$1=""; sub(/^ /, ""); print $$0}')
CMD_SOURCE 					= $(addprefix cmd/,$(CMD_DIRS))
BINARIES_TARGETS 			= $(addprefix binary-,$(CMD_DIRS))
BINARIES_OUTPUT_DIRECTORIES = $(addprefix dist/,$(CMD_DIRS))

# AWS.
AWS_REGION      ?= ap-southeast-2
STACK_NAME      = $(PROJECT)-$*
AWS_ACCOUNT_ID	?= $(shell aws sts get-caller-identity --query 'Account' --output text)
ECR             = $$(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
BUCKET			?= jmpa-io-artifacts

# Funcs.
get_last_element = $(lastword $(subst /, ,$1)) # Splits a string by '/' and retrieves the last element in the given array.

# Check deps.
ifndef CI
EXECUTABLES ?= awk aws cfn-lint column find go golangci-lint grep hadolint sam zip
MISSING := $(strip $(foreach bin,$(EXECUTABLES),$(if $(shell command -v $(bin) 2>/dev/null),,$(bin))))
$(if $(MISSING),$(error Please install: $(MISSING)))
endif

# The default command executed when running `make`.
.DEFAULT_GOAL:=	help

# ┬  ┬ ┌┐┌┌┬┐
# │  │ │││ │
# ┴─┘┴ ┘└┘ ┴

.PHONY: lint
lint: lint-sh lint-go lint-cf lint-sam lint-docker ## ** Lints everything.

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

# ┌┬┐┌─┐┌─┐┌┬┐
#  │ ├┤ └─┐ │
#  ┴ └─┘└─┘ ┴

.PHONY: test
test: test-go ## ** Tests everything.

.PHONY: test-go
test-go: dist/coverage.txt ## Runs Go tests.
dist/coverage.txt: dist
	@test -z "$(CI)" || echo "##[group]Unit tests."
ifeq ($(GO_FILES),)
	@echo "No *.go files to test."
else
	@go version
	CGO_ENABLED=1 go test -short -coverprofile=$@ \
    	-covermode=atomic -race -vet=off ./...
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: code-coverage
code-coverage: dist/coverage.txt ## Generates a Go code coverage report, broken-down by function, to stdout.
	@if [[ -f $< ]]; then \
		test -z "$(CI)" || echo "##[group]Code coverage."; \
		go tool cover -func=$<; \
		test -z "$(CI)" || echo "##[endgroup]"; \
	fi

.PHONY: code-coverage-html
code-coverage-html: dist/coverage.txt ## Generates a Go code HTML coverage report, rendered in the default browser.
	@if [[ -f $< ]]; then \
		go tool cover -html=$<; \
	fi

# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘

.PHONY: binaries binaries-all
binaries: $(BINARIES_TARGETS) ## ** Builds ALL binaries for the $(BUILDING_OS) environment.
binaries-all:  ## ** Builds ALL binaries for ALL supported operating systems.
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

## Builds a binary, for the given service, for the $(BUILDING_OS) environment.
binary-%: cmd/%/main.go dist/%
	$(call build_binary,$(BUILDING_OS))

# ┬  ┌─┐┌┬┐┌┐ ┌┬┐┌─┐
# │  ├─┤│││├┴┐ ││├─┤
# ┴─┘┴ ┴┴ ┴└─┘─┴┘┴ ┴

# Moves the bootstrap, for the given service, into the dist directory.
bootstrap-%: dist/% cmd/%/bootstrap
	@cp cmd/$*/bootstrap dist/$*/

# Invokes the given service locally, if able.
invoke-%: cmd/%/local.sh binary-% bootstrap-%
	@$<

# ┌┬┐┌─┐┌─┐┬┌─┌─┐┬─┐
#  │││ ││  ├┴┐├┤ ├┬┘
# ─┴┘└─┘└─┘┴ ┴└─┘┴└─

.PHONY: images
images: $(foreach image,$(IMAGES),image-$(image)) ## ** Builds ALL docker images for each service.

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
push: images-development ## ** Pushes ALL docker images to ECR.
images-development: $(foreach image,$(IMAGES),push-$(image))

define push_image
.PHONY: push-$1
## Pushes the docker image for a given service to AWS ECR.
push-$1: image-$1
	@test -z "$(CI)" || echo "##[group]Pushing $(strip $(call get_last_element,$(subst .,,$1))) image."
	docker tag $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):$(COMMIT) $(PROJECT)/$(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
	docker tag $(if $(filter $1,$(PROJECT)),$1,$(PROJECT)/$(strip $(call get_last_element,$1))):latest $(PROJECT)/$(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):latest
	docker push $(PROJECT)/$(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
	docker push $(PROJECT)/$(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):latest
	@test -z "$(CI)" || echo "##[endgroup]"
endef
$(foreach image,$(IMAGES),$(eval $(call push_image,$(image))))

.PHONY: pull
pull: $(foreach image,$(IMAGES),pull-$(image)) ## ** Pulls ALL docker images for every service.

define pull_image
.PHONY: pull-$1
## For the given service, pulls the associated docker image from AWS ECR.
pull-$1:
	docker pull $(strip $(ECR))/$(strip $(call get_last_element,$(subst .,,$1))):$(COMMIT)
endef
$(foreach image,$(IMAGES),$(eval $(call pull_image,$(image))))

# ┌┬┐┌─┐┌─┐┬  ┌─┐┬ ┬
#  ││├┤ ├─┘│  │ │└┬┘
# ─┴┘└─┘┴  ┴─┘└─┘ ┴

.PHONY: auth-aws
auth-aws: ## Checks current auth to AWS; An error indicates an issue with auth to an AWS account.
	@aws sts get-caller-identity &>/dev/null

# Sets PRIMARY_SERVICES to be SERVICES, so you can use either in a Makefile.
PRIMARY_SERVICES ?= $(SERVICES)

.PHONY: deploy $(PRIMARY_SERVICES) $(SECONDARY_SERVICES) $(TERTIARY_SERVICES) $(QUATERNARY_SERVICES) $(QUINARY_SERVICES)
deploy: $(PRIMARY_SERVICES) $(SECONDARY_SERVICES) $(TERTIARY_SERVICES) $(QUATERNARY_SERVICES) $(QUINARY_SERVICES) ## ** Deploys the Cloudformation template for ALL services.

## Deploys the Cloudformation template for the given service.
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
endif

## Packages the Cloudformation template for the given service.
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

# ┌┬┐┬┌─┐┌─┐
# ││││└─┐│
# ┴ ┴┴└─┘└─┘

.PHONY: generate-readme
generate-readme: ## Generates a README.md, using a template.
	@bin/README.sh jmpa-io

.PHONY: update-template
update-template: ## Pulls changes from root-template into this repository.
	git fetch template
	git merge template/main --allow-unrelated-histories

.PHONY: clean
clean: ## Removes generated files and folders, resetting this repository back to its initial clone state.
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
			nb = sub(/^## /, "", helpMessage); \
			if (nb == 0) { \
				helpMessage = $$0; \
				nb = sub(/^[^:]*:.* ## /, "", helpMessage); \
			} \
			if (nb) print "\033[33m" target "\033[0m" helpMessage; \
		} { helpMessage = $$0 } \
	'; \
	awk "$$awk_script" $(MAKEFILE_LIST) | column -ts:

# ┬  ┬┌─┐┌┬┐
# │  │└─┐ │
# ┴─┘┴└─┘ ┴

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

# ┌┐┌┌─┐┌┬┐┌─┐┌─┐
# ││││ │ │ ├┤ └─┐
# ┘└┘└─┘ ┴ └─┘└─┘

# ASCII art in this file are generated from: https://patorjk.com/software/taag/#p=display&h=0&v=0&f=Calvin%20S&t=notes%0A
