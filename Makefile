# Top-level convenience commands for the k8s-labs course.
#
# Usage:
#   make preflight                # verify tooling is installed
#   make cluster                  # create the default kind cluster
#   make cluster-down             # destroy the cluster
#   make reset                    # destroy + recreate the cluster
#   make lab LAB=03               # print the lab README
#   make verify LAB=03            # run the automated grader for lab 03
#   make grade                    # run every grader and emit report.md
#   make context                  # set kubectl context to the kind cluster
#
# LAB is a two-digit prefix (e.g. 03 or 12). The Makefile resolves it to the
# matching directory under labs/.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

CLUSTER_NAME ?= k8s-labs
CLUSTER_CONFIG ?= clusters/kind-basic.yaml

# Resolve a lab number (e.g. 03) to the matching directory.
LAB ?=
LAB_DIR = $(shell if [ -n "$(LAB)" ]; then ls -d labs/$(LAB)-* 2>/dev/null | head -n1; fi)

.PHONY: help
help: ## Show this help
	@awk 'BEGIN { FS = ":.*?## "; printf "Targets:\n" } \
	     /^[a-zA-Z0-9_-]+:.*?## / { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: preflight
preflight: ## Verify docker, kind, kubectl, helm, jq are installed
	@./bin/preflight.sh

.PHONY: cluster
cluster: ## Create the default kind cluster
	@./bin/cluster-up.sh "$(CLUSTER_NAME)" "$(CLUSTER_CONFIG)"

.PHONY: cluster-down
cluster-down: ## Delete the kind cluster
	@./bin/cluster-down.sh "$(CLUSTER_NAME)"

.PHONY: reset
reset: cluster-down cluster ## Recreate the cluster from scratch

.PHONY: context
context: ## Switch kubectl context to the kind cluster
	@kubectl config use-context kind-$(CLUSTER_NAME)

.PHONY: lab
lab: _require_lab ## Print the README for the requested LAB
	@cat $(LAB_DIR)/README.md

.PHONY: verify
verify: _require_lab ## Run the automated grader for LAB
	@bash $(LAB_DIR)/verify.sh

.PHONY: grade
grade: ## Run every grader and emit report.md
	@./bin/grade.sh | tee report.md

.PHONY: test-solutions
test-solutions: ## Apply every reference solution then run its verifier
	@./bin/test-solutions.sh

.PHONY: clean-lab
clean-lab: _require_lab ## Delete all resources created by LAB
	@if [ -x $(LAB_DIR)/cleanup.sh ]; then \
	  bash $(LAB_DIR)/cleanup.sh; \
	else \
	  echo "No cleanup.sh for $(LAB_DIR); delete resources manually."; \
	fi

.PHONY: _require_lab
_require_lab:
	@if [ -z "$(LAB)" ]; then \
	  echo "error: set LAB=NN (e.g. make verify LAB=03)" >&2; exit 2; \
	fi
	@if [ -z "$(LAB_DIR)" ] || [ ! -d "$(LAB_DIR)" ]; then \
	  echo "error: no lab matches LAB=$(LAB)" >&2; exit 2; \
	fi
