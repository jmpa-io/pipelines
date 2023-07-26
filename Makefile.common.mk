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
SH_FILES		:= $(shell find . -name "*.sh" -type f) # A list of ALL sh files in the repository.
GO_FILES 		:= $(shell find . -name "*.go" -type f) # A list of ALL Go files in the repository.
CF_FILES		:= $(shell find ./cf -name 'template.yml' -type f) # A list of ALL template.yml files in the repository.
SAM_FILES		:= $(shell find ./cf -name 'template.yaml' -type f) # A list of ALL template.yaml files in the repository.
CF_DIRS			:= $(shell find ./cf -mindepth 1 -maxdepth 1 -type d) # A list of dirs directly under ./cf.
CMD_DIRS		:= $(shell find ./cmd -mindepth 1 -maxdepth 1 -type d) # A list of dirs directly under ./cmd.
# ---
CMD_SOURCE		= $(shell find cmd/$* -type f 2>/dev/null) # The source for a command.
BINARIES 		= $(patsubst %,dist/%,$(shell find cmd/* -maxdepth 0 -type d -exec basename {} \; 2>/dev/null)) # A list of ALL binaries in the repository.
BINARIES_LINUX	= $(patsubst %,%-linux,$(BINARIES)) # A list of ALL linux binaries in the repository.
# ---
AWS_REGION		?= ap-southeast-2 # The region to use when doing things in AWS.
STACK_NAME		= $(PROJECT)-$* # The format of the generated name for Cloudformation stacks in AWS.
# ---
ECR				= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PROJECT):$* # The ecr url for the authed AWS account.

# Check deps.
EXECUTABLES ?= awk column grep go golangci-lint find aws zip cfn-lint sam
MISSING := $(strip $(foreach bin,$(EXECUTABLES),$(if $(shell command -v $(bin) 2>/dev/null),,$(bin))))
$(if $(MISSING),$(error Please install: $(MISSING); $(PATH)))

# The default command executed when running `make`.
.DEFAULT_GOAL:=	help

# ┬  ┬┌─┐┌┬┐
# │  │└─┐ │
# ┴─┘┴└─┘ ┴

.PHONY: list-cf
list-cf: ## Lists ALL dirs under ./cf.
	@echo $(CF_DIRS)

.PHONY: list-cmd
list-cmd: ## Lists ALL dirs under ./cmd.
	@echo $(CMD_DIRS)

.PHONY: list-binaries
list-binaries: ## Lists ALL binaries.
	@echo $(BINARIES)

.PHONY: list-binaries-linux
list-binaries-linux: ## Lists ALL Linux binaries.
	@echo $(BINARIES_LINUX)

.PHONY: list-images
list-images: ## Lists ALL docker images for every service.
	@echo $(IMAGES)

.PHONY: list-deploy
list-deploy: ## Lists ALL services to deploy.
	@echo $(SERVICES)

# ┬  ┬ ┌┐┌┌┬┐
# │  │ │││ │
# ┴─┘┴ ┘└┘ ┴

.PHONY: lint
lint: lint-sh lint-go lint-cf lint-sam ## ** Lints everything.

.PHONY: lint-sh
lint-sh: ## Lints shell files.
	@test -z "$(CI)" || echo "##[group]Linting sh."
ifeq ($(strip $(SH_FILES)),)
	@echo "No *.sh files to lint."
else
	@find . -type f -name "*.sh" -exec shellcheck '{}' \+ || true
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

.PHONY: lint-cf
lint-cf: ## Lint CF templates.
	@test -z "$(CI)" || echo "##[group]Linting cf."
ifeq ($(strip $(CF_FILES)),)
	@echo "No ./cf/*/template.yml files to lint."
else
	@find ./cf -type f -name 'template.yml' -exec cfn-lint -r $(AWS_REGION) -t '{}' \; || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: lint-sam
lint-sam: ## Lint SAM templates.
	@test -z "$(CI)" || echo "##[group]Linting sam."
ifeq ($(strip $(SAM_FILES)),)
	@echo "No ./cf/*/template.yaml files to lint."
else
	@find ./cf -type f -name 'template.yaml' -exec sam validate --region $(AWS_REGION)-t '{}' \; || true
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
	@CGO_ENABLED=1 go test -short -coverprofile=dist/coverage.txt \
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
dist: ; mkdir dist

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

# ┌┬┐┌─┐┌─┐┬┌─┌─┐┬─┐
#  │││ ││  ├┴┐├┤ ├┬┘
# ─┴┘└─┘└─┘┴ ┴└─┘┴└─

.PHONY: images
images: image-$(IMAGES) ## ** Builds ALL docker images for each service.

## Builds the docker image for the given service.
image-%: dist/%-linux cmd/%/Dockerfile
	@test -z "$(CI)" || echo "##[group]Building $@ image."
	docker build -t $(PROJECT)/$*:$(COMMIT) -t $(PROJECT)/$*:latest -f ./cmd/$*/Dockerfile .
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: push
push: images-development ## ** Pushes ALL docker images to ECR.
images-development: push-$(IMAGES)

## Pushes the docker image for a given service to AWS ECR.
push-%: image-%
	@test -z "$(CI)" || echo "##[group]Pushing $@ image."
	docker tag $(PROJECT)/$*:$(COMMIT) $(ECR):$(COMMIT)
	docker tag $(PROJECT)/$*:latest $(ECR):latest
	docker push $(ECR):$(COMMIT)
	docker push $(ECR):latest
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: promote
promote: images-production ## ** Promotes ALL docker images from DEV -> PROD.

.PHONY: promote-$(ENVIRONMENT)
promote-%: ## Promotes a given docker image between the AWS ECR for DEV -> PROD.
	@test -z "$(CI)" || echo "##[group]Promoting $@ image."
ifeq "$(ENVIRONMENT)" "prod"
	docker pull $(ECR_DEV):$(COMMIT)
	docker tag $(ECR_DEV):$(COMMIT) $(ECR_PROD):$(COMMIT)
	docker tag $(ECR_DEV):$(COMMIT) $(ECR_PROD):latest
	docker push $(ECR_PROD):$(COMMIT)
	docker push $(ECR_PROD):latest
else
	@echo "ENVIRONMENT must be set to `prod` for $<."
endif
	@test -z "$(CI)" || echo "##[endgroup]"

.PHONY: pull
pull: ## ** Pulls ALL docker images for every service.

.PHONY: pull-$(IMAGES)
pull-%: ## For the given service, pulls the associated docker image from AWS ECR.
	docker pull $(ECR):$(COMMIT)

# ┌┬┐┌─┐┌─┐┬  ┌─┐┬ ┬
#  ││├┤ ├─┘│  │ │└┬┘
# ─┴┘└─┘┴  ┴─┘└─┘ ┴

.PHONY: deploy $(COMPONENT)
deploy: $(SERVICES) ## ** Deploys the Cloudformation template for ALL services.

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
