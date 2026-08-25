
#
# This Makefile is designed to be generic across ALL repositories.
#
# The original source code for this Makefile can be found here:
# https://github.com/jmpa-io/root-template/blob/main/Makefile.common.mk
#
# PLEASE NOTE:
# Any changes to this Makefile should be made there instead.

# ---

# The name of the project.
#
# PLEASE NOTE:
# This value must be given any other Makefile that references this common Makefile.
ifndef PROJECT
$(error PROJECT not defined, missing from Makefile?)
endif

#
# ┌─┐┬ ┬┌┐┌┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
# ├┤ │ │││││   │ ││ ││││└─┐
# └  └─┘┘└┘└─┘ ┴ ┴└─┘┘└┘└─┘o
#

# Determines if a given value is found within another given value, such as
# checking if a given string is found within a given array.
define contains
$(if $(findstring $(1),$(2)),true,false)
endef

# Determines if a given file is considered a SAM template.
define is_sam_template
$(if $(shell awk 'NR==3 && /Transform: AWS::Serverless-/' $(1)),$(1))
endef

# Converts a given path-to-a-Dockerfile to a human readable label associated
# with this project. This makes it easier to do further actions with the
# Dockerfile, like tagging and pushing the Docker image to AWS ECR.
define determine_image_name_from_dockerfile
$(patsubst cmd/%/Dockerfile,$(PROJECT)/%, \
	$(patsubst Dockerfile,$(PROJECT),$(1)) \
)
endef

# Determines the name of the Makefile target associated with the human readable
# label associated with this project.
define determine_target_from_image_name
$(patsubst $(PROJECT),image-root, \
	$(patsubst $(PROJECT)/%,image-%,$(1)) \
)
endef

# Replaces the '.' character with the '-' character, for when names of resources
# are sensitive or require specific regex patterns (such as website urls used
# as the name for a GitHub repository).
define replace_dots_with_dashes
$(subst .,-,$(1))
endef

# Determines if the given string should have added ".exe" to the end of it.
define add_windows_suffix
$(if $(findstring windows,$(1)),.exe,)
endef


#
# ┬  ┬┌─┐┬─┐┬┌─┐┌┐ ┬  ┌─┐┌─┐
# └┐┌┘├─┤├┬┘│├─┤├┴┐│  ├┤ └─┐
#  └┘ ┴ ┴┴└─┴┴ ┴└─┘┴─┘└─┘└─┘o
#

# The shell used when executing commands.
SHELL = /bin/sh

# The default command executed when `make` is run without arguments.
.DEFAULT_GOAL := help

# Suppress "Entering/Leaving directory" messages in recursive make calls.
MAKEFLAGS += --no-print-directory

# ---

# The deployment environment (eg. dev, sit, prod).
# PLEASE NOTE: This affects which config is used when deploying.
ENVIRONMENT ?= local

# The git commit hash.
# PLEASE NOTE: This affects how unique or identifiable deployed resources are.
COMMIT ?= $(shell git describe --tags --always)

# The name of this repository, derived from the 'git root directory'.
# PLEASE NOTE: This affects how identifiable deployed resources are.
REPO = $(shell basename $(shell git rev-parse --show-toplevel))

# The GitHub organization associated with this repository.
ORG ?= jmpa-io

# ---

# The directory to place any output, artifacts, or downloaded files.
OUTPUT_DIR ?= dist

# The log level for any scripts that support it.
LOG_LEVEL ?= info

# ---

# The Python interpreter to use for running Python scripts and tests.
PYTHON ?= python3

# ---

# The id of the user.
UID := $(shell id -u)

# The id of the group.
GID := $(shell id -g)

# ---

# A list of supported operating systems for building binaries.
SUPPORTED_OPERATING_SYSTEMS = linux darwin windows

# The operating system currently being used by the host.
OS := $(shell uname | tr '[:upper:]' '[:lower:]')

# The operating system to target when building binaries.
BUILDING_OS ?= $(OS)

# A list of supported CPU architectures for compiling binaries.
# PLEASE NOTE: run 'go tool dist list' to see all supported architectures for Go.
SUPPORTED_ARCHITECTURES = arm64 amd64

# The CPU architecture currently being used by the host.
ARCH := $(shell uname -m)
ifeq ($(ARCH),x86_64)
	ARCH = amd64
else ifeq ($(ARCH),aarch64)
	ARCH = arm64
endif

# The CPU architecture to target when building binaries.
BUILDING_ARCH ?= $(ARCH)

# ---

# The root directory containing Cloudformation templates.
CLOUDFORMATION_ROOT_DIRECTORY ?= ./cf

# ---

# The paths to any given Git submodules found in this repository.
GIT_SUBMODULES := $(shell git config --file $(shell while [ ! -d .git ]; do cd ..; done; pwd)/.gitmodules --get-regexp path | awk '{ print $$2 }')

# A filter for ignoring Git submodules when using 'find' commands in this Makefile.
FILTER_IGNORE_SUBMODULES = $(foreach module,$(GIT_SUBMODULES),-not \( -path "./$(module)" -o -path "./$(module)/*" \))

# ---

# All '.*sh' files in the repository (excluding submodules).
SH_FILES := $(shell find . $(FILTER_IGNORE_SUBMODULES) -name "*.sh" -type f 2>/dev/null)

# All PowerShell scripts in the repository (excluding submodules).
POWERSHELL_FILES := $(shell find . $(FILTER_IGNORE_SUBMODULES) -name "*.ps1" -type f 2>/dev/null)

# All Go files in the repository (excluding submodules).
GO_FILES := $(shell find . $(FILTER_IGNORE_SUBMODULES) -name "*.go" -type f 2>/dev/null)

# All Python files in the repository (excluding submodules).
PYTHON_FILES := $(shell find . $(FILTER_IGNORE_SUBMODULES) -name "*.py" -type f 2>/dev/null)

# All C++ files in the repository (excluding submodules).
CPP_FILES := $(shell find . $(FILTER_IGNORE_SUBMODULES) -name "*.cpp" -type f 2>/dev/null)

# All Cloudformation templates & SAM templates in the './cf' directory (excluding submodules).
TEMPLATE_FILES := $(shell find ./cf $(FILTER_IGNORE_SUBMODULES) -name "template.yml" -type f 2>/dev/null)

# All SAM templates in the repository (excluding submodules).
SAM_TEMPLATE_FILES := $(foreach file,$(TEMPLATE_FILES),$(call is_sam_template,$(file)))

# All Cloudformation templates in the repository (excluding submodules).
CLOUDFORMATION_TEMPLATE_FILES := $(filter-out $(SAM_TEMPLATE_FILES),$(TEMPLATE_FILES))

# GitHub Actions workflow files in the '.github/workflows' directory (excluding submodules).
WORKFLOW_FILES := $(shell find .github/workflows $(FILTER_IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -name '*.yml' -type f 2>/dev/null)

# ---

# All Dockerfiles in the repository (excluding submodules).
DOCKERFILES := \
		$(subst ./,, \
			$(addsuffix /Dockerfile, \
				$(shell find . $(FILTER_IGNORE_SUBMODULES) -name 'Dockerfile' -exec dirname {} \; 2>/dev/null) \
			) \
		)

# A list of Docker images created from the Dockerfiles in the repository.
IMAGES := \
	$(foreach dockerfile,$(DOCKERFILES), \
		$(call determine_image_name_from_dockerfile,$(dockerfile)) \
	)

# A collection of targets used to build Docker images within this Makefile.
BUILD_TARGETS_FOR_IMAGES := \
	$(foreach image,$(IMAGES), \
		$(call determine_target_from_image_name,$(image)) \
	)

# Tags applied to Docker images when building, pushing, or promoting images.
TAGS ?= $(COMMIT) latest

# ---

# The Cloudformation stack name used when deploying a Cloudformation stack.
STACK_NAME = $(call replace_dots_with_dashes,$(PROJECT)-$*-$(ENVIRONMENT))

# The region used when deploying a Cloudformation stack, or other aws-cli
# commands, in the authed AWS account.
AWS_REGION ?= ap-southeast-2

# The id of the authed AWS account.
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query 'Account' --output text)

# The default path to an AWS ECR repository for the authed AWS account.
ECR = $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

# The name of a generic S3 bucket in the AWS Account for storing artifacts.
ifndef BUCKET
BUCKET = $(shell aws ssm get-parameter --name "/common/artifacts-bucket" --query 'Parameter.Value' --output text 2>/dev/null)
endif

# The path to the `.params` file. This doesn't check if it exists, it's just
# the expected path this file MAY exist at.
PARAMS_FILE ?= cf/.params/$(ENVIRONMENT).json

# ---

# The generic environment to promote from; This could have ties from Artifactory, or AWS ECR, etc.
PROMOTE_FROM_ENVIRONMENT ?= $(ENVIRONMENT)

# ---

# The AWS region to promote Docker images from.
PROMOTE_FROM_AWS_REGION ?= $(AWS_REGION)

# The id of the AWS account to promote Docker images from.
PROMOTE_FROM_AWS_ACCOUNT_ID ?= $(AWS_ACCOUNT_ID)

# The default path to an AWS ECR repository in another AWS account.
# PLEASE NOTE: This is used when promoting Docker images between AWS accounts.
PROMOTE_FROM_ECR = $(PROMOTE_FROM_AWS_ACCOUNT_ID).dkr.ecr.$(PROMOTE_FROM_AWS_REGION).amazonaws.com

# ---

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

else ifeq ($(OS),windows)

  # Native Windows (cmd.exe / PowerShell / MSYS2 / Chocolatey make) is not a
  # supported configuration for this Makefile. Running under WSL is the
  # recommended approach on Windows — WSL reports 'linux' via uname, so the
  # linux block above applies and no changes are needed here.
  #
  # If native Windows support is added in future, SED_FLAGS and FILE_SIZE
  # would need platform-appropriate equivalents defined here.

endif

#
# ┌─┐┬─┐┌─┐  ┌─┐┬─┐┌┬┐┬┌─┐┌─┐┌─┐┌┬┐┌─┐
# ├─┘├┬┘├┤───├─┤├┬┘ │ │├┤ ├─┤│   │ └─┐
# ┴  ┴└─└─┘  ┴ ┴┴└─ ┴ ┴└  ┴ ┴└─┘ ┴ └─┘
#

$(OUTPUT_DIR): ## Creates the output folder.
$(OUTPUT_DIR):
	@mkdir -p $@

$(OUTPUT_DIR)/%: ## Creates the output folder, for a given service.
$(OUTPUT_DIR)/%: $(OUTPUT_DIR)
	@mkdir -p $@

PHONY += \
  $(OUTPUT_DIR) \
  $(OUTPUT_DIR)/%

#
# ┌┬┐┌─┐┌─┐┌─┐┌┐┌┌┬┐┌─┐┌┐┌┌─┐┬┌─┐┌─┐
#  ││├┤ ├─┘├┤ │││ ││├┤ ││││  │├┤ └─┐
# ─┴┘└─┘┴  └─┘┘└┘─┴┘└─┘┘└┘└─┘┴└─┘└─┘o
#

ifndef CI

# Below is a list of core dependencies required for running this Makefile.
DEPENDENCIES ?= \
	awk \
	column \
	find \
	grep \
	zip

# Below aggregates all language-specific dependencies required for this Makefile.
DEPENDENCIES += \
  $(BASH_DEPENDENCIES) \
  $(PYTHON_DEPENDENCIES) \
  $(GO_DEPENDENCIES) \
  $(DOCKER_DEPENDENCIES) \
  $(AWS_DEPENDENCIES)

# Bash-specific dependencies.
BASH_DEPENDENCIES ?= \
  bash \
  shellcheck

# Python-specific dependencies.
PYTHON_DEPENDENCIES ?= \
  python \
  ruff

# Go-specific dependencies.
GO_DEPENDENCIES ?= \
  go \
  golangci-lint

# Docker-specific dependencies.
DOCKER_DEPENDENCIES ?= \
  docker \
  hadolint

# AWS-specific dependencies.
AWS_DEPENDENCIES ?= \
  aws \
  cfn-lint \
  sam

# Additional jmpa-io specific dependencies.
DEPENDENCIES += \
  actionlint \
  cpplint

# Determines if there are any missing dependencies.
MISSING := \
  $(strip \
    $(foreach binary,$(DEPENDENCIES), \
      $(if $(shell command -v $(binary) 2>/dev/null),,$(binary)) \
    ) \
  )

# Stops the Makefile execution if there are any missing dependencies.
$(if $(MISSING),$(error Please install: $(MISSING)))

endif

# ---

install-deps: ## ** Installs ALL dependencies required for running services in this repository.
install-deps: \
  install-python-deps

#
# Python.
#

# Determine which requirements file to use at the root (supports any ENVIRONMENT).
ifeq ($(ENVIRONMENT),local)
  PYTHON_REQUIREMENTS_FILE = requirements-local.txt
else
  PYTHON_REQUIREMENTS_FILE = requirements.txt
endif

# Find all per-project requirements files, but not the root one itself.
PYTHON_REQUIREMENTS_FILES = $(shell find . -type f -name '$(PYTHON_REQUIREMENTS_FILE)' ! -path "./$(PYTHON_REQUIREMENTS_FILE)")

install-root-python-deps: # Installs root requirements file (if found).
install-root-python-deps:
	@if [ -f $(PYTHON_REQUIREMENTS_FILE) ]; then \
		pip3 install -r $(PYTHON_REQUIREMENTS_FILE); \
	else \
		echo "No root $(PYTHON_REQUIREMENTS_FILE) found, skipping.."; \
	fi

install-python-deps: ## ** Installs ALL Python requirements files in this repository.
install-python-deps: install-root-python-deps
	@for req in $(PYTHON_REQUIREMENTS_FILES); do \
		pip3 install -r "$$req"; \
	done

PHONY += \
  install-deps \
  install-python-deps \
  install-root-python-deps

#
# ┬  ┬┌┐┌┌┬┐
# │  ││││ │
# ┴─┘┴┘└┘ ┴ o
#

#
# Vars.
#

# The path to the Actionlint config file, in relation to this Makefile.
ACTIONLINT_CONFIG_FILE ?= actionlint.yaml

#
# Targets.
#

lint: ## ** Lints everything.
lint: \
	lint-sh \
	lint-powershell \
	lint-go \
	lint-cpp \
	lint-py \
	lint-cf \
	lint-sam \
	lint-docker \
	lint-workflows

lint-sh: ## Lints scripts.
lint-sh:
	@test -z "$(CI)" || echo "##[group]Linting scripts."
ifeq ($(SH_FILES),)
	@echo "No *.sh files to lint."
else
	@$(foreach file,$(SH_FILES), - shellcheck "$(file)";)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-powershell: ## Lints PowerShell scripts.
lint-powershell:
	@test -z "$(CI)" || echo "##[group]Linting PowerShell scripts."
ifeq ($(POWERSHELL_FILES),)
	@echo "No *.ps1 files to lint."
else
	@$(foreach file,$(POWERSHELL_FILES), \
		pwsh -Command "Invoke-ScriptAnalyzer -Path '$(file)' -Severity Warning,Error" || true; \
	)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-go: ## Lints Go files.
lint-go:
	@test -z "$(CI)" || echo "##[group]Linting Go."
ifeq ($(GO_FILES),)
	@echo "No *.go files to lint."
else
	@golangci-lint run -v --allow-parallel-runners ./... --timeout 5m || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-cpp: ## Lints C++ files.
lint-cpp:
	@test -z "$(CI)" || echo "##[group]Linting C++."
ifeq ($(CPP_FILES),)
	@echo "No *.cpp files to lint."
else
	@cpplint --filter=-legal/copyright $(CPP_FILES)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-py: ## Lints Python files.
lint-py:
	@test -z "$(CI)" || echo "##[group]Linting Python."
ifeq ($(PYTHON_FILES),)
	@echo "No Python files to lint."
else
	@ruff check $(PYTHON_FILES) || true
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-cf: ## Lints Cloudformation templates.
lint-cf:
	@test -z "$(CI)" || echo "##[group]Linting Cloudformation templates."
ifeq ($(CLOUDFORMATION_TEMPLATE_FILES),)
	@echo "No Cloudformation templates found to lint."
else
	@$(foreach file,$(CLOUDFORMATION_TEMPLATE_FILES), \
		cfn-lint -r $(AWS_REGION) -t $(file) || true; \
		aws cloudformation validate-template --region $(AWS_REGION) --template-body file://$(file) || true; \
	)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-sam: ## Lints AWS SAM templates.
lint-sam:
	@test -z "$(CI)" || echo "##[group]Linting AWS SAM templates."
ifeq ($(SAM_TEMPLATE_FILES),)
	@echo "No AWS SAM templates found to lint."
else
	@$(foreach file,$(SAM_TEMPLATE_FILES), \
		- sam validate --region $(AWS_REGION) -t "$(file)"; \
	)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-docker: ## Lints Dockerfiles.
lint-docker:
	@test -z "$(CI)" || echo "##[group]Linting Dockerfiles."
ifeq ($(DOCKERFILES),)
	@echo "No Dockerfiles to lint."
else
	@$(foreach file,$(DOCKERFILES), \
		hadolint "$(file)" || true; \
	)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

lint-workflows: ## Lints GitHub Action workflows.
lint-workflows:
	@test -z "$(CI)" || echo "##[group]Linting GitHub Action workflows."
ifeq ($(WORKFLOW_FILES),)
	@echo "No GitHub Action workflows to lint."
else
	@$(foreach file,$(WORKFLOW_FILES), \
		actionlint -config-file "$(ACTIONLINT_CONFIG_FILE)" "$(file)" || true; \
	)
endif
	@test -z "$(CI)" || echo "##[endgroup]"

PHONY += lint \
         lint-sh \
         lint-powershell \
         lint-go \
         lint-cpp \
         lint-py \
         lint-cf \
         lint-sam \
         lint-docker \
         lint-workflows

#
# ┌┬┐┌─┐┌─┐┌┬┐
#  │ ├┤ └─┐ │
#  ┴ └─┘└─┘ ┴ o
#

test: ## ** Tests everything.
test: \
	test-go \
	test-py

PHONY += test

#
# Go.
#

test-go: ## Runs Go tests.
test-go: $(OUTPUT_DIR)/coverage.txt
$(OUTPUT_DIR)/coverage.txt: # Generates the $(OUTPUT_DIR)/coverage.txt file.
$(OUTPUT_DIR)/coverage.txt: # PLEASE NOTE: Adding this target to PHONY will generate this
$(OUTPUT_DIR)/coverage.txt: #              file every time this target is called.
$(OUTPUT_DIR)/coverage.txt: #              Otherwise `make clean` will have to be run.
$(OUTPUT_DIR)/coverage.txt: $(OUTPUT_DIR)
	@test -z "$(CI)" || echo "##[group]Unit tests for Go."
ifeq ($(GO_FILES),)
	@echo "No Go files found to test or generate code-coverage."
else
	@go version
	CGO_ENABLED=1 go test \
		-short \
		-coverprofile=$@ \
		-covermode=atomic \
		-race \
		-vet=off \
		./...
endif
	@test -z "$(CI)" || echo "##[endgroup]"

PHONY += test-go \
         $(OUTPUT_DIR)/coverage.txt

#
# Python.
#

test-py: ## Runs Python tests.
test-py: $(OUTPUT_DIR)/coverage.xml
$(OUTPUT_DIR)/coverage.xml: # Generates the $(OUTPUT_DIR)/coverage.xml file.
$(OUTPUT_DIR)/coverage.xml: # PLEASE NOTE: Adding this target to PHONY will generate this
$(OUTPUT_DIR)/coverage.xml: #              file every time this target is called.
$(OUTPUT_DIR)/coverage.xml: #              Otherwise `make clean` will have to be run.
$(OUTPUT_DIR)/coverage.xml: $(OUTPUT_DIR)
	@test -z "$(CI)" || echo "##[group]Unit tests for Python."
ifeq ($(PYTHON_FILES),)
	@echo "No Python files found to test or generate code-coverage."
else
	@$(PYTHON) --version
	$(PYTHON) -m pytest \
		-v \
		--tb=short \
		--cov=src \
		--cov-config=$(shell while [ ! -d .git ]; do cd ..; done; pwd)/.coveragerc \
		--cov-report=xml:$@ \
		--cov-report=term \
		.
endif
	@test -z "$(CI)" || echo "##[endgroup]"

PHONY += test-py \
         $(OUTPUT_DIR)/coverage.xml

#
# ┌─┐┌─┐┌┬┐┌─┐  ┌─┐┌─┐┬  ┬┌─┐┬─┐┌─┐┌─┐┌─┐
# │  │ │ ││├┤   │  │ │└┐┌┘├┤ ├┬┘├─┤│ ┬├┤
# └─┘└─┘─┴┘└─┘  └─┘└─┘ └┘ └─┘┴└─┴ ┴└─┘└─┘o
#

# The default code-coverage format.
CODE_COVERAGE_FORMAT ?= default

# A list of supported code-coverage formats.
SUPPORTED_CODE_COVERAGE_FORMATS = default html

# Validates if the given code-coverage format is a supported format.
VALID_CODE_COVERAGE_FORMAT := $(strip $(call contains,$(CODE_COVERAGE_FORMAT),$(SUPPORTED_CODE_COVERAGE_FORMATS)))
ifeq ($(VALID_CODE_COVERAGE_FORMAT),false)
$(error "'$(CODE_COVERAGE_FORMAT)' is not a supported format for generating code-coverage in this Makefile")
endif

code-coverage: ## ** Generates code coverage for every programming language commonly used.
code-coverage: \
	code-coverage-go \
	code-coverage-py

PHONY += code-coverage

#
# Go.
#

define code-coverage-go-default
go tool cover -func=$<
endef

define code-coverage-go-html
go tool cover -html=$<
endef

code-coverage-go: ## Generates a code coverage report for Go, formatted by {cyan}$(CODE_COVERAGE_FORMAT){nocolor}.
code-coverage-go: $(OUTPUT_DIR)/coverage.txt
	@if [ -f $< ]; then \
		test -z "$(CI)" || echo "##[group]Code coverage for Go."; \
		$(call code-coverage-go-$(CODE_COVERAGE_FORMAT)); \
		test -z "$(CI)" || echo "##[endgroup]"; \
	fi

PHONY += code-coverage-go

#
# Python.
#

define code-coverage-py-default
$(PYTHON) -m coverage report
endef

define code-coverage-py-html
$(PYTHON) -m coverage html -d $(OUTPUT_DIR)/htmlcov && echo "HTML coverage report generated in $(OUTPUT_DIR)/htmlcov/index.html"
endef

code-coverage-py: ## Generates a code coverage report for Python, formatted by {cyan}$(CODE_COVERAGE_FORMAT){nocolor}.
code-coverage-py: $(OUTPUT_DIR)/coverage.xml
	@if [ -f $< ]; then \
		test -z "$(CI)" || echo "##[group]Code coverage for Python."; \
		$(call code-coverage-py-$(CODE_COVERAGE_FORMAT)); \
		test -z "$(CI)" || echo "##[endgroup]"; \
	fi

PHONY += code-coverage-py

#
# ┌─┐┌─┐┬─┐┌┬┐┌─┐┌┬┐
# ├┤ │ │├┬┘│││├─┤ │
# └  └─┘┴└─┴ ┴┴ ┴ ┴
#

format: ## ** Formats ALL the code it can.
format: \
  format-py

format-py: ## Formats Python code.
format-py:
	@ruff format $(PYTHON_FILES)

PHONY += \
  format \
  format-py

#
# ┌─┐┬─┐┌─┐  ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├─┘├┬┘├┤───├┴┐││││├─┤├┬┘│├┤ └─┐
# ┴  ┴└─└─┘  └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘o
#

# A list of supported programming languages for building binaries in this Makefile.
SUPPORTED_LANGUAGES_FOR_BUILDING_BINARIES = \
	cpp \
	go

binary-%-%-%: ## Creates a binary for the given service {green}$(1){nocolor}, operating system {green}$(2){nocolor}, and CPU architecture {green}$(3){nocolor}.
binary-%-%-%: #
binary-%-%-%: #  PLEASE NOTE:
binary-%-%-%: #  This target is 'dummy' and is just for adding a comment to the help page.

PHONY += binary-%-%-%

#
# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐       ┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐  ───  │  ++
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘       └─┘  o
#

# A list of directories under './cmd/*' that contain 'main.cpp' (excluding submodules).
CMD_SERVICES_CPP := $(shell find cmd/* $(FILTER_IGNORE_SUBMODULES) -name main.cpp -maxdepth 1 -type f -exec dirname {} \; 2>/dev/null | awk -F/ '{$$1=""; sub(/^ /, ""); print $$0}')

# A function to set the C++ compiler based on BUILDING_OS and BUILDING_ARCH.
define set_cpp_compiler
ifeq ($(BUILDING_OS), linux)
    ifeq ($(BUILDING_ARCH), amd64)
        CPP_COMPILER := g++
    else ifeq ($(BUILDING_ARCH), arm64)
        CPP_COMPILER := aarch64-linux-gnu-g++
    endif
else ifeq ($(BUILDING_OS), darwin)
    ifeq ($(BUILDING_ARCH), amd64)
        CPP_COMPILER := o64-clang++
    else ifeq ($(BUILDING_ARCH), arm64)
        CPP_COMPILER := arm-none-linux-gnueabihf-g++
    endif
else ifeq ($(BUILDING_OS), windows)
    ifeq ($(BUILDING_ARCH), amd64)
        CPP_COMPILER := x86_64-w64-mingw32-g++
    else ifeq ($(BUILDING_ARCH), arm64)
				# NOTE: waiting for this to be merged: https://github.com/Windows-on-ARM-Experiments/mingw-woarm64-build/
        CPP_COMPILER := g++
    endif
endif
endef

print-cpp-version: # Prints the installed C++ compiler version.
print-cpp-version:
	$(eval $(call set_cpp_compiler))
	@test -z "$(CI)" || echo "##[group]C++ compiler version ($(CPP_COMPILER))."
	@$(CPP_COMPILER) --version
	@test -z "$(CI)" || echo "##[endgroup]"

# Builds a C++ binary for the given service, OS, and arch.
# $(1) = service (eg. hello).
# $(2) = operating system (OS) (eg. windows).
# $(3) = cpu architecture (arch) (eg. amd64).
define build_binary_cpp
	$(eval $(call set_cpp_compiler))
	@test -z "$$CI" || echo "##[group]Building binary $(1)-$(2)-$(3)."
	$(CPP_COMPILER) cmd/$*/*.cpp -Wall -Wextra -o dist/$(1)/$(1)-$(2)-$(3)$(call add_windows_suffix,$(2))
	@test -z "$$CI" || echo "##[endgroup]"
endef

binary-cpp-%: ## Create a C++ binary for the given service, using $(BUILDING_OS) and $(BUILDING_ARCH).
binary-cpp-%: cmd/%/main.cpp dist/% print-cpp-version
	$(call build_binary_cpp,$*,$(BUILDING_OS),$(BUILDING_ARCH))

build-cpp-%: # Builds & executes the given C++ service using the host $(OS) & $(ARCH).
build-cpp-%: binary-cpp-%
	@dist/$*/$*-$(OS)-$(ARCH)$(call add_windows_suffix, $(OS))

binaries-cpp-%: ## Creates a C++ binary for all supported OS and ARCH for the given service.
binaries-cpp-%:
	@$(foreach os,$(SUPPORTED_OPERATING_SYSTEMS), \
		$(foreach arch,$(SUPPORTED_ARCHITECTURES), \
			BUILDING_OS=$(os) BUILDING_ARCH=$(arch) \
			$(MAKE) --no-print-directory binary-cpp-$*; \
		) \
	)

binaries-cpp: ## Builds C++ binaries for every C++ service.
binaries-cpp:
	@$(foreach service,$(CMD_SERVICES_CPP), \
		$(MAKE) --no-print-directory binaries-cpp-$(service); \
	)

PHONY += print-cpp-version


#
# ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐       ┌─┐┌─┐
# ├┴┐││││├─┤├┬┘│├┤ └─┐  ───  │ ┬│ │
# └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘       └─┘└─┘o
#

# A list of directories under './cmd/*' that contain 'main.go' (excluding submodules).
CMD_SERVICES_GO := $(shell find cmd/* $(FILTER_IGNORE_SUBMODULES) -name main.go -maxdepth 1 -type f -exec dirname {} \; 2>/dev/null | awk -F/ '{$$1=""; sub(/^ /, ""); print $$0}')

print-go-version: # Prints the installed Go version.
print-go-version:
	@test -z "$(CI)" || echo "##[group]Go version."
	@go version
	@test -z "$(CI)" || echo "##[endgroup]"

# Builds a Go binary for the given service, OS, and arch.
# $(1) = service (eg. hello).
# $(2) = operating system (OS) (eg. windows).
# $(3) = cpu architecture (arch) (eg. amd64).
define build_binary_go
	@test -z "$$CI" || echo "##[group]Building binary $(1)-$(2)-$(3)."
	GOOS=$(2) GOARCH=$(3) \
	go build --trimpath \
		-tags lambda.norpc \
		-ldflags "-w -s -X main.Version=$(COMMIT)" \
		-o dist/$(1)/$(1)-$(2)-$(3)$(call add_windows_suffix,$(2)) ./cmd/$(1)
	@test -z "$$CI" || echo "##[endgroup]"
endef

binary-go-%: ## Create a Go binary for the given service, using {green}$(BUILDING_OS){nocolor} and {green}$(BUILDING_ARCH){nocolor}.
binary-go-%: cmd/%/main.go dist/%
	$(call build_binary_go,$*,$(BUILDING_OS),$(BUILDING_ARCH))

build-go-%: # Builds & executes the given Go service using the host {green}$(OS){nocolor} & {green}$(ARCH){nocolor}.
build-go-%: binary-go-%
	@dist/$*/$*-$(OS)-$(ARCH)$(call add_windows_suffix, $(OS))

binaries-go-%: ## Creates a Go binary for all supported OS and ARCH for the given service.
binaries-go-%: print-go-version
	@$(foreach os,$(SUPPORTED_OPERATING_SYSTEMS), \
		$(foreach arch,$(SUPPORTED_ARCHITECTURES), \
			BUILDING_OS=$(os) BUILDING_ARCH=$(arch) \
			$(MAKE) --no-print-directory binary-go-$*; \
		) \
	)

binaries-go: ## ** Builds Go binaries for every Go service.
binaries-go:
	@$(foreach service,$(CMD_SERVICES_GO), \
		$(MAKE) --no-print-directory binaries-go-$(service); \
	)

PHONY += print-go-version

#
# ┌─┐┌─┐┌─┐┌┬┐  ┌┐ ┬┌┐┌┌─┐┬─┐┬┌─┐┌─┐
# ├─┘│ │└─┐ │───├┴┐││││├─┤├┬┘│├┤ └─┐
# ┴  └─┘└─┘ ┴   └─┘┴┘└┘┴ ┴┴└─┴└─┘└─┘o
#

binaries: ## ** Builds binaries for each supported language only for the {green}$(BUILDING_OS){nocolor} & {green}$(BUILDING_ARCH){nocolor} environment.
binaries:
	$(foreach lang,$(SUPPORTED_LANGUAGES_FOR_BUILDING_BINARIES), \
		$(MAKE) --no-print-directory binaries-$(lang); \
	)

PHONY += binaries

#
# ┬  ┌─┐┌┬┐┌┐ ┌┬┐┌─┐
# │  ├─┤│││├┴┐ ││├─┤
# ┴─┘┴ ┴┴ ┴└─┘─┴┘┴ ┴ o
#

bootstrap-%: # Moves the bootstrap, for the given service, into the dist directory.
bootstrap-%: $(OUTPUT_DIR)/% cmd/%/bootstrap
	@cp cmd/$*/bootstrap $(OUTPUT_DIR)/$*

invoke-%: ## Invokes the given service locally, using aws-sam-cli, if able.
invoke-%: cmd/%/local.sh binary-% bootstrap-%
	@$<

#
# ┌┬┐┌─┐┌─┐┬┌─┌─┐┬─┐
#  │││ ││  ├┴┐├┤ ├┬┘
# ─┴┘└─┘└─┘┴ ┴└─┘┴└─o
#

# Configuration for local dev runs.
DOCKER_MOUNT_PATH ?= /app

print-docker-version: # Prints the installed Docker version.
print-docker-version:
	@test -z "$(CI)" || echo "##[group]Docker version."
	@docker version
	@test -z "$(CI)" || echo "##[endgroup]"

# Builds a Docker image for a given service.
# $(1) = The path to the Dockerfile.
# $(2) = The name to tag for the built Dockerfile (aka. a Docker image).
define build_image
	@test -z "$(CI)" || echo "##[group]Building $(2)."
	docker build \
		$(patsubst %,-t $(2):%,$(TAGS)) \
		-f $(1) .
	@test -z "$(CI)" || echo "##[endgroup]"
endef

image-%: ## Builds a Docker image using `{magenta}./cmd/<service>/Dockerfile{nocolor}`.
image-%: # PLEASE NOTE: PHONY isn't declared for this target on purpose.
image-%: #              This should be done in any Makefiles reading this file instead.
image-%: cmd/%/Dockerfile print-docker-version
	$(call build_image,$<,$(call determine_image_name_from_dockerfile,$<))

image-root: ## Builds a Docker image using `{magenta}./Dockerfile{nocolor}`.
image-root: Dockerfile print-docker-version
	$(call build_image,$<,$(call determine_image_name_from_dockerfile,$<))

docker-images: images
images: ## ** Builds ALL the Docker images in this repository.
images: print-docker-version
	@$(foreach dockerfile,$(DOCKERFILES), \
		$(call build_image,$(dockerfile),$(call determine_image_name_from_dockerfile,$(dockerfile))) \
	)

local: docker
docker: ## Builds & runs the root Docker image locally; mounts the repository under {cyan}$(DOCKER_MOUNT_PATH){nocolor}.
docker: image-root
	@test -z "$(CI)" || echo "##[group]Running repository in root Docker image."
	docker run -it --rm \
		-v $(CURDIR):$(DOCKER_MOUNT_PATH) \
		-v $(HOME)/.aws:/root/.aws:ro \
		-e AWS_PROFILE \
		-e PYTHONHTTPSVERIFY=0 \
		-e PYTHONWARNINGS="ignore:Unverified HTTPS request" \
		-e CURL_CA_BUNDLE="" \
		-e AWS_CA_BUNDLE="" \
		$(call determine_image_name_from_dockerfile,Dockerfile):$(COMMIT)
	@test -z "$(CI)" || echo "##[endgroup]"

# Pushes a Docker image to AWS ECR.
# $(1) = The name of the service to push to AWS ECR.
# PLEASE NOTE: This target assumes the `docker push` is already authenticated
#              to push to AWS ECR. If not, this should be managed outside this
#              Makefile and on the local machine running this command or in CI/CD.
define push_image
	@test -z "$(CI)" || echo "##[group]Tagging $(1) for AWS ECR in $(AWS_ACCOUNT_ID)."
	$(foreach tag,$(TAGS), \
		docker tag $(1) $(ECR)/$(1):$(tag); \
	)
	@test -z "$(CI)" || echo "##[endgroup]"
	@test -z "$(CI)" || echo "##[group]Pushing $(1) to AWS ECR in $(AWS_ACCOUNT_ID)."
	@$(foreach tag,$(TAGS), \
		docker push $(ECR)/$(1):$(tag); \
	)
	@test -z "$(CI)" || echo "##[endgroup]"
endef

push-%: ## For the given service, pushes a Docker image to AWS ECR.
push-%: # PLEASE NOTE: PHONY isn't declared for this target on purpose.
push-%: #              This should be done in any Makefiles reading this file instead.
push-%: image-%
	$(call push_image,$(call determine_image_name_from_dockerfile,cmd/$*/Dockerfile))

push-root: ## Pushes the Docker image built from `{magenta}./Dockerfile{nocolor}`.
push-root: image-root
	$(call push_image,$(call determine_image_name_from_dockerfile,Dockerfile))

push: ## ** Pushes ALL Docker images for ALL services in this repository to AWS ECR.
push: images
	$(foreach image,$(IMAGES), \
		$(call push_image,$(image)); \
	)

# Pulls a Docker image from AWS ECR.
# $(1) = The name of the service to pull from in AWS ECR.
define pull_image
	@test -z "$(CI)" || echo "##[group]Pulling $(1) from AWS ECR in $(AWS_ACCOUNT_ID)."
	@docker pull $(ECR)/$(1):$(COMMIT)
	@test -z "$(CI)" || echo "##[endgroup]"
endef

pull-%: ## Pulls a Docker image, for the given service, from AWS ECR.
pull-%: cmd/%/Dockerfile
	$(call pull_image,$(call determine_image_name_from_dockerfile,$<))

pull-root: ## Pulls a Docker image, built from `{magenta}./Dockerfile{nocolor}`, from AWS ECR.
pull-root: Dockerfile
	$(call pull_image,$(call determine_image_name_from_dockerfile,$<))

pull: ## ** Pulls ALL Docker images for ALL services from AWS ECR for this repository.
pull:
	$(foreach image,$(IMAGES), \
		$(call pull_image,$(image)); \
	)

# Promotes a Docker image from ECR in one AWS account to another.
# $(1) = The name of the service to promote between AWS accounts.
define promote_image
	@test -z "$(CI)" || echo "##[group]Pulling $(1) from AWS ECR in $(PROMOTE_FROM_AWS_ACCOUNT_ID)."
	@docker pull $(PROMOTE_FROM_ECR)/$(1):$(COMMIT)
	@test -z "$(CI)" || echo "##[endgroup]"

	@test -z "$(CI)" || echo "##[group]Tagging $(1) for AWS ECR in $(AWS_ACCOUNT_ID)."
	$(foreach tag,$(TAGS), \
		docker tag $(PROMOTE_FROM_ECR)/$(1):$(COMMIT) $(ECR)/$(1):$(tag); \
	)
	@test -z "$(CI)" || echo "##[endgroup]"
	@test -z "$(CI)" || echo "##[group]Pushing $(1) to AWS ECR in $(AWS_ACCOUNT_ID)."
	@$(foreach tag,$(TAGS), \
		docker push $(ECR)/$(1):$(tag); \
	)
	@test -z "$(CI)" || echo "##[endgroup]"
endef

promote-%: ## Promotes a Docker image for a given service to another AWS account.
promote-%: cmd/%/Dockerfile
	$(call promote_image,$(call determine_image_name_from_dockerfile,$<))

promote-root: # Promotes the root Docker image for this repository to another AWS account.
promote-root: Dockerfile
	$(call promote_image,$(call determine_image_name_from_dockerfile,$<))

promote: ## ** Promotes ALL Docker images for ALL services in this repository to another AWS account.
promote:
	@$(foreach image,$(IMAGES), \
		$(call promote_image,$(image)); \
	)

PHONY += print-docker-version \
         images docker-images push pull promote \
         image-root push-root pull-root promote-root \
         docker local

#
# ┌┬┐┌─┐┌─┐┬  ┌─┐┬ ┬
#  ││├┤ ├─┘│  │ │└┬┘
# ─┴┘└─┘┴  ┴─┘└─┘ ┴ o
#

# The default number of service groups to be created.
DEFAULT_NUM_SERVICE_GROUPS ?= 99

# Sets the maxiumum number of service groups to be created.
#
# PLEASE NOTE:
# The more service groups there are, the slower this Makefile executes.
NUM_SERVICE_GROUPS := $(DEFAULT_NUM_SERVICE_GROUPS)

# Sets PRIMARY_SERVICES to be SERVICES, so either can be used in subsequent Makefiles.
SERVICE_GROUP_1 ?= $(SERVICES)

# Determines which service groups have assigned targets to deploy.
SERVICE_GROUPS :=
SERVICE_GROUPS_WITH_VALUES :=
$(foreach i, $(shell seq 1 $(NUM_SERVICE_GROUPS)), \
  $(if $(value SERVICE_GROUP_$(i)), \
    $(eval SERVICE_GROUPS := $(SERVICE_GROUPS) SERVICE_GROUP_$(i)) \
	$(eval SERVICE_GROUPS_WITH_VALUES := $(SERVICE_GROUPS_WITH_VALUES) SERVICE_GROUP_$(i) = $(value SERVICE_GROUP_$(i))) \
  ) \
)

# A list of services under './$(CLOUDFORMATION_ROOT_DIRECTORY)' (except submodules) that contain Cloudformation templates.
CF_SERVICES := $(shell find ./$(CLOUDFORMATION_ROOT_DIRECTORY) $(FILTER_IGNORE_SUBMODULES) -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

deploy: ## ** Deploys the Cloudformation template for ALL services.
deploy: $(foreach service,$(SERVICE_GROUPS),$($(service)))

deploy-%: ## Deploys the Cloudformation template for the given service.
deploy-%: $(CLOUDFORMATION_ROOT_DIRECTORY)/%/package.yml
ifeq ($(strip $(ENVIRONMENT)),)
	$(error ENVIRONMENT not defined; please populate it before deploying)
else ifeq ($(ENVIRONMENT),local)
	$(error Cannot deploy to '$(ENVIRONMENT)' environment. Please set ENVIRONMENT to a non-$(ENVIRONMENT) value)
else
	@test -z "$(CI)" || echo "##[group]Deploying $*."
	aws cloudformation deploy \
    --stack-name $(STACK_NAME) \
    --template-file $< \
		--region $(AWS_REGION) \
		$(shell [ -n "$(FILE_SIZE)" ] && [ $(FILE_SIZE) -gt 51200 ] && echo "--s3-bucket $(BUCKET)") \
		--parameter-overrides \
        Organization=$(ORG) \
        Repository=$(REPO) \
        Project=$(PROJECT) \
        Component=$* \
        Revision=$(COMMIT) \
        Environment=$(ENVIRONMENT) \
      $(if $(wildcard $(PARAMS_FILE)),$(shell jq -r 'map("\(.ParameterKey)=\(.ParameterValue)") | join(" ")' $(PARAMS_FILE)),) \
      $(if $(ADDITIONAL_PARAMETER_OVERRIDES),$(ADDITIONAL_PARAMETER_OVERRIDES),) \
    --tags \
        organization=$(ORG) \
        repository=$(REPO) \
        project=$(PROJECT) \
        component=$* \
        revision=$(COMMIT) \
        environment=$(ENVIRONMENT) \
		$(if $(ADDITIONAL_STACK_TAGS),$(ADDITIONAL_STACK_TAGS),) \
    --capabilities \
        CAPABILITY_IAM \
        CAPABILITY_NAMED_IAM \
        CAPABILITY_AUTO_EXPAND \
		--no-fail-on-empty-changeset
	@test -z "$(CI)" || echo "##[endgroup]"
endif

$(CLOUDFORMATION_ROOT_DIRECTORY)/%/package.yml: ## Packages the Cloudformation template for the given service.
$(CLOUDFORMATION_ROOT_DIRECTORY)/%/package.yml: $(CLOUDFORMATION_ROOT_DIRECTORY)/%/template.yml
ifeq ($(strip $(ENVIRONMENT)),)
	$(error ENVIRONMENT not defined; please populate it before deploying)
else ifeq ($(ENVIRONMENT),local)
	$(error Cannot deploy to '$(ENVIRONMENT)' environment. Please set ENVIRONMENT to a non-$(ENVIRONMENT) value)
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

PHONY += deploy

# PLEASE NOTE:
# SERVICE_GROUPS *could* be added to PHONY here, but the aim is for
# these to be controlled from the Makefile where they are declared.
# Do this there, instead of here.

#
# ┌─┐┬─┐┬┌┐┌┌┬┐
# ├─┘├┬┘││││ │
# ┴  ┴└─┴┘└┘ ┴
#

# PLEASE NOTE:
# - All targets that begin with 'print-' are automatically added to PHONY.
# - See the PHONY section below for how this works.

# A simple command to help format the output of an array.
FORMAT_ARRAY ?= tr '[:space:]' '\n'

print-%: ## Prints the value of any given Makefile variable.
print-%:
	@echo "$($*)"

print-array-%: ## Prints each item of a space-separated variable on its own line.
print-array-%:
	@echo "$($*)" | $(FORMAT_ARRAY)

print-PHONY: # A special target to print ALL PHONY values found in this Makefile.
print-PHONY:
	@echo $(PHONY) | $(FORMAT_ARRAY)

PHONY += \
	print-% \
	print-array-% \
	print-PHONY

#
# ┬  ┬┌─┐┌┬┐
# │  │└─┐ │
# ┴─┘┴└─┘ ┴ o
#

# NOTE: All targets that begin with 'list-' are automatically added to PHONY.
#		See the PHONY section below for how this works.

list-shell: # Lists the shell the Makefile uses when executing targets.
list-shell:
	@echo $(SHELL)

list-default-goal: # Lists the default Makefile goal set.
list-default-goal:
	@echo $(.DEFAULT_GOAL)

# ---

list-project: # Lists the project set for this repository.
list-project:
	@echo $(PROJECT)

list-env: list-environment
list-environment: # Lists the environment used.
list-environment:
	@echo $(ENVIRONMENT)

list-revision: list-commit
list-commit: # Lists the current git commit hash.
list-commit:
	@echo $(COMMIT)

list-repo: list-repository
list-repository: # Lists the name of the repository.
list-repository:
	@echo $(REPO)

list-org: list-organization
list-organization: # Lists the GitHub organization associated with this repository.
list-organization:
	@echo $(ORG)

# ---

list-os: list-operating-system
list-operating-system: # Lists the operating system detected by this Makefile.
list-operating-system:
	@echo $(OS)

list-building-os: list-building-operating-system
list-building-operating-system: # Lists the operating system used when building a binary in this Makefile.
list-building-operating-system:
	@echo $(BUILDING_OS)

list-supported-os: list-supported-operating-systems
list-supported-operating-systems: # Lists the operating systems supported by this Makefile.
list-supported-operating-systems:
	@echo $(SUPPORTED_OPERATING_SYSTEMS) | $(FORMAT_ARRAY)

list-arch: list-architecture
list-architecture: # Lists the CPU architecture detected by this Makefile.
list-architecture:
	@echo $(ARCH)

list-building-arch: list-building-architecture
list-building-architecture: # Lists the CPU architecture used when building a binary in this Makefile.
list-building-architecture:
	@echo $(BUILDING_ARCH)

list-supported-arch: list-supported-architectures
list-supported-architectures: # Lists the CPU architectures supported by this Makefile.
list-supported-architectures:
	@echo $(SUPPORTED_ARCHITECTURES) | $(FORMAT_ARRAY)

# ---

list-sh: list-shell-scripts
list-shell-scripts: # Lists ALL found shell scripts in this repository.
list-shell-scripts:
	@echo $(SH_FILES) | $(FORMAT_ARRAY)

list-go: list-go-files
list-go-files: # Lists ALL found Go files in this repository.
list-go-files:
	@echo $(GO_FILES) | $(FORMAT_ARRAY)

list-cpp: list-cpp-files
list-cpp-files: # Lists ALL found C++ files in this repository.
list-cpp-files:
	@echo $(CPP_FILES) | $(FORMAT_ARRAY)

list-py: list-python-files
list-python-files: # Lists ALL found Python files in this repository.
list-python-files:
	@echo $(PYTHON_FILES) | $(FORMAT_ARRAY)

list-sam: list-sam-templates
list-sam-templates: # Lists ALL found SAM templates in this repository.
list-sam-templates:
	@echo $(SAM_TEMPLATE_FILES) | $(FORMAT_ARRAY)

list-cf: list-cf-templates
list-cf-templates: # Lists ALL found Cloudformation templates in this repository.
list-cf-templates:
	@echo $(CLOUDFORMATION_TEMPLATE_FILES) | $(FORMAT_ARRAY)

list-workflows: # Lists ALL found GitHub Action workflows in this repository.
list-workflows:
	@echo $(WORKFLOW_FILES) | $(FORMAT_ARRAY)

# ---

list-dockerfiles: list-Dockerfiles
list-Dockerfiles: # Lists ALL found Dockerfiles in this repository.
list-Dockerfiles:
	@echo $(DOCKERFILES) | $(FORMAT_ARRAY)

list-images: list-docker-images
list-docker-images: # Lists ALL Docker images built / can-be-built from this Makefile.
list-docker-images:
	@echo $(IMAGES) | $(FORMAT_ARRAY)

list-docker-image-build-targets: list-image-build-targets
list-image-build-targets: # Lists ALL targets generated from this Makefile to build a Docker image from the found Dockerfiles.
list-image-build-targets:
	@echo $(BUILD_TARGETS_FOR_IMAGES) | $(FORMAT_ARRAY)

list-tags: list-docker-tags
list-docker-tags: # Lists ALL tags used when tagging or pulling Docker images.
list-docker-tags:
	@echo $(TAGS) | $(FORMAT_ARRAY)

# ---

list-region: list-aws-region
list-aws-region: # Lists the configured AWS region used when deploying / configuring resources locally.
list-aws-region:
	@echo $(AWS_REGION)

list-account-id: list-aws-account-id
list-aws-account-id: # Lists the authed AWS account id.
list-aws-account-id:
	@echo $(AWS_ACCOUNT_ID)

list-bucket: list-generic-bucket
list-generic-bucket: # Lists the generic S3 bucket in the authed AWS account.
list-generic-bucket:
	@echo $(BUCKET)

list-ecr: # Lists the default path to AWS ECR in the authed AWS account.
list-ecr:
	@echo $(ECR)

# ---

list-promote-region: list-promote-aws-region
list-promote-from-region: list-promote-from-aws-region
list-promote-from-aws-region: # Lists the AWS region used when promoting a Docker image.
list-promote-from-aws-region:
	@echo $(PROMOTE_FROM_AWS_REGION)

list-promote-id: list-promote-from-aws-account-id
list-promote-from-id: list-promote-from-aws-account-id
list-promote-from-aws-account-id: # Lists the AWS account id used when promoting a Docker image.
list-promote-from-aws-account-id:
	@echo $(PROMOTE_FROM_AWS_ACCOUNT_ID)

list-promote-ecr: list-promote-from-ecr
list-promote-from-ecr: # Lists the AWS ECR repository path used when promoting a Docker image.
list-promote-from-ecr:
	@echo $(PROMOTE_FROM_ECR)

# ---

list-submodules: list-git-submodules
list-git-submodules: # Lists the path to any Git submodules in this repository.
list-git-submodules:
	@echo $(GIT_SUBMODULES)

list-filter-ignore-submodules: # Lists the filter used in many Makefile targets to ignore paths to Git submodules in this repository.
list-filter-ignore-submodules:
	@echo $(FILTER_IGNORE_SUBMODULES)

# ---

# Adds ALL 'list-' targets in the Makefile to PHONY.
PHONY += $(shell grep -E '^list-[^:]*:' $(MAKEFILE_LIST) | awk -F':' '{print $$2}' | sort -u)

list-phony: list-PHONY
list-PHONY: # Lists ALL PHONY values found in this Makefile.
list-PHONY:
	@echo $(PHONY) | $(FORMAT_ARRAY)


#
# ┬  ┬┌─┐┬  ┬┌┬┐┌─┐┌┬┐┌─┐┬─┐┌─┐
# └┐┌┘├─┤│  │ ││├─┤ │ │ │├┬┘└─┐
#  └┘ ┴ ┴┴─┘┴─┴┘┴ ┴ ┴ └─┘┴└─└─┘o
#

# Validates if a given {green}$(BUILDING_OS){nocolor} is found within SUPPORTED_OPERATING_SYSTEMS.
VALID_OS := $(strip $(call contains,$(BUILDING_OS),$(SUPPORTED_OPERATING_SYSTEMS)))
ifeq ($(VALID_OS),false)
$(error "'$(BUILDING_OS)' is not a supported operating system in this Makefile")
endif

# Validates if a given {green}$(BUILDING_ARCH){nocolor} is found within SUPPORTED_ARCHITECTURES.
VALID_ARCH := $(strip $(call contains,$(BUILDING_ARCH),$(SUPPORTED_ARCHITECTURES)))
ifeq ($(VALID_ARCH),false)
$(error "'$(BUILDING_ARCH)' is not a supported CPU architecture in this Makefile")
endif

#
# ┌┬┐┬┌─┐┌─┐
# ││││└─┐│
# ┴ ┴┴└─┘└─┘ o
#

.FORCE: # A dummy target to force execution of dependent targets.
.FORCE:

update-template: ## Pulls changes from the pre-defined template into this repository.
update-template:
	git fetch template
	git merge template/main --allow-unrelated-histories

clean: ## Resets this repository back to state it was when first cloned.
clean:
	@test -z "$(CI)" || echo "##[group]Cleaning up."
	@rm -f coverage.* traces.*
	@rm -rf dist
	@test -z "$(CI)" || echo "##[endgroup]"

help: ## Prints this help page.
help:
	@echo "Available targets:"
	@awk_script='\
		BEGIN { \
			use_color_global = (ENVIRON["NO_COLOR"] == "" ? 1 : 0); \
			colors["red"] = "\033[91m"; \
			colors["green"] = "\033[92m"; \
			colors["yellow"] = "\033[93m"; \
			colors["blue"] = "\033[94m"; \
			colors["magenta"] = "\033[95m"; \
			colors["cyan"] = "\033[96m"; \
			colors["nocolor"] = "\033[0m"; \
		} \
		function color_code(name) { return (name in colors ? colors[name] : "") } \
		function apply_tokens(s, use_color,    result, current_color, pos, tokenStart, tokenLen, tok, segment) { \
			result = ""; current_color = ""; pos = 1; \
			while (match(substr(s, pos), /\{(red|green|yellow|blue|magenta|cyan|nocolor)\}/)) { \
				tokenStart = pos + RSTART - 1; \
				tokenLen = RLENGTH; \
				segment = substr(s, pos, tokenStart - pos); \
				if (use_color && current_color != "") \
					result = result current_color segment "\033[0m"; \
				else \
					result = result segment; \
				tok = substr(s, tokenStart+1, tokenLen-2); \
				if (tok == "nocolor") current_color = ""; \
				else current_color = color_code(tok); \
				pos = tokenStart + tokenLen; \
			} \
			segment = substr(s, pos); \
			if (use_color && current_color != "") \
				result = result current_color segment "\033[0m"; \
			else \
				result = result segment; \
			if (use_color) { \
				gsub(/\*\*/, colors["red"] "**" colors["nocolor"], result); \
				gsub(/---/, colors["magenta"] "---" colors["nocolor"], result); \
				gsub(/%/, colors["blue"] "%" colors["nocolor"], result); \
			} \
			return result; \
		} \
		/^[a-zA-Z\-\\_0-9%\/$$]+:/ { \
			target = $$1; \
			gsub("\\$$1", "%", target); \
			nb = sub(/^## /, "", helpMessage); \
			if (nb == 0) { \
				helpMessage = $$0; \
				nb = sub(/^[^:]*:.* ## /, "", helpMessage); \
			} \
			if (nb) { \
				coloredMessage = apply_tokens(helpMessage, use_color_global); \
				print colors["yellow"] target colors["nocolor"] " " coloredMessage; \
			} \
		} { helpMessage = $$0 } \
	'; \
	awk "$$awk_script" $(MAKEFILE_LIST) | column -ts:

PHONY += \
	update-template \
	clean help

#
#  ┌─┐┬ ┬┌─┐┌┐┌┬ ┬
#  ├─┘├─┤│ ││││└┬┘
# o┴  ┴ ┴└─┘┘└┘ ┴
#

# PHONY tells make that the given target doesn't deal with files specifically,
# and that the target itself is in essence "fake". There are some thing that are
# not performed, like cleaning up generated files, when telling make a target is
# PHONY. Populate $(PHONY) with any targets you want this for.
# PLEASE NOTE: this must be last in this file.
.PHONY: $(PHONY)
