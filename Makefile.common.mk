#
# This Makefile is generic across all repositories:
# https://github.com/jmpa-io/root-template/blob/main/Makefile.common.mk
#

# Check project variables are given.
ifndef PROJECT
$(error PROJECT not defined, missing Makefile?)
endif

# Vars.
SHELL           = /bin/sh
ENVIRONMENT     ?= dev
COMMIT          = $(shell git describe --tags --always)
REPO            = $(shell basename $(shell git rev-parse --show-toplevel))
FILE_SIZE		= $(shell stat -f '%z' $<)

# Files.
SH_FILES        := $(shell find . -name "*.sh" -type f 2>/dev/null)
GO_FILES        := $(shell find . -name "*.go" -type f 2>/dev/null)
CF_FILES        := $(shell find ./cf -name 'template.yml' -type f 2>/dev/null)
SAM_FILES       := $(shell find ./cf -name 'template.yaml' -type f 2>/dev/null)
CF_DIRS         := $(shell find ./cf -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
CMD_DIRS        := $(shell find ./cmd -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
IMAGES          := $(patsubst .,$(PROJECT),$(patsubst ./%,%,$(shell find . -name 'Dockerfile' -type f -exec dirname {} \; 2>/dev/null)))

# Binaries.
CMD_SOURCE      = $(shell find cmd/$* -type f 2>/dev/null)
BINARIES        = $(patsubst %,dist/%,$(shell find cmd/* -maxdepth 0 -type d -exec basename {} \; 2>/dev/null))
BINARIES_LINUX  = $(patsubst %,%-linux,$(BINARIES))

# AWS.
AWS_REGION      ?= ap-southeast-2
STACK_NAME      = $(PROJECT)-$*
AWS_ACCOUNT_ID	= $(shell aws sts get-caller-identity --query 'Account' --output text)
ECR             = $$(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
BUCKET			= jmpa-io-artifacts

# Funcs.
get_last_element = $(lastword $(subst /, ,$1)) # Splits a string by '/' and retrieves the last element in the array.

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
	golangci-lint run -v --allow-parallel-runners
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-cf
lint-cf: ## Lints CF templates.
	@test -z "$(CI)" || echo "##[group]Linting cf."
ifeq ($(CF_FILES),)
	@echo "No ./cf/*/template.yml files to lint."
else
	find ./cf -type f -name 'template.yml' -exec cfn-lint -r $(AWS_REGION) -t '{}' \; || true
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
test-go: dist ## Tests Go + generates coverage report.
	@test -z "$(CI)" || echo "##[group]Unit tests."
ifeq ($(GO_FILES),)
	@echo "No *.go files to test."
else
	@go version
	CGO_ENABLED=1 go test -short -coverprofile=dist/coverage.txt \
		-covermode=atomic -race -vet=off ./... \
		&& go tool cover -func=dist/coverage.txt
endif
	@test -z "$(CI)" || echo "##[endgroup]"

# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘

.PHONY: binaries
binaries: $(BINARIES) ## ** Builds ALL binaries.

## Creates the dist directory, if missing.
dist:
	@mkdir dist

## Builds the binary for the given service (for the local machine platform - GOOS).
binary-%: dist/%
dist/%: $(CMD_SOURCE)
	@test -z "$(CI)" || echo "##[group]Building $@"
	@go version
	go build --trimpath -ldflags "-w -s \
		    -X version.Version=$(COMMIT)" \
		    -o $@ ./cmd/$*
	@test -z "$(CI)" || echo "##[endgroup]"

## Builds the binary for the given service (for Linux).
binary-%-linux: dist/%-linux
dist/%-linux: $(CMD_SOURCE)
	@test -z "$(CI)" || echo "##[group]Building $@"
	@go version
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build --trimpath -ldflags "-w -s \
		    -X version.Version=$(COMMIT)" \
		    -o $@ ./cmd/$*
	@test -z "$(CI)" || echo "##[endgroup]"

## Zips the given service.
dist/%.zip: dist/%-linux
	@zip -rjDm $@ dist/$*-linux

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

.PHONY: deploy $(PRIMARY_SERVICES) $(SECONDARY_SERVICES) $(TERTIARY_SERVICES)
deploy: $(PRIMARY_SERVICES) $(SECONDARY_SERVICES) $(TERTIARY_SERVICES) ## ** Deploys the Cloudformation template for ALL services.

## Deploys the Cloudformation template for the given service.
deploy-%: cf/%/package.yml
	@test -z "$(CI)" || echo "##[group]Deploying $*."
	aws cloudformation deploy \
		--region $(AWS_REGION) \
		--template-file $< \
		$(shell [[ $(FILE_SIZE) -ge 51200 ]] && echo "--s3-bucket $(BUCKET)") \
		--stack-name $(STACK_NAME) \
		--tags \
			repository=$(REPO) \
			project=$(PROJECT) \
			component=$* \
			revision=$(COMMIT) \
		--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
		--parameter-overrides Component=$* Revision=$(COMMIT) Environment=$(ENVIRONMENT) \
		$(if $(wildcard cf/params/$(ENVIRONMENT).json),$(shell jq -r 'map("\(.ParameterKey)=\(.ParameterValue)") | join(" ")' ./cf/params/$(ENVIRONMENT).json),) \
		$(if $(ADDITIONAL_PARAMETER_OVERRIDES),$(ADDITIONAL_PARAMETER_OVERRIDES),) \
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
		--s3-bucket $(BUCKET)
	@test -z "$(CI)" || echo "##[endgroup]"

# ┌┬┐┬┌─┐┌─┐
# ││││└─┐│
# ┴ ┴┴└─┘└─┘

.PHONY: generate-readme
generate-readme: ## Generates a README.md, using a template.
	@bin/README.sh jmpa-io

.PHONY: update-template
update-template: ## Pulls changes from root-template into this repository.
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
	@awk_script='\
		/^[a-zA-Z\-\_0-9%\/$$]+:/ { \
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
list-binaries: # Lists ALL binaries.
	@echo $(BINARIES)

.PHONY: list-binaries-linux
list-binaries-linux: # Lists ALL Linux binaries.
	@echo $(BINARIES_LINUX)

.PHONY: list-images
list-images: # Lists ALL docker images for every service.
	@echo $(IMAGES)

.PHONY: list-deploy
list-deploy: # Lists ALL services to deploy.
	@echo $(PRIMARY_SERVICES)
	@echo $(SECONDARY_SERVICES)
	@echo $(TERTIARY_SERVICES)
