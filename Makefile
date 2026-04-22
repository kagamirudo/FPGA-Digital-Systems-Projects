# ============================================================================
# Makefile — Git workflow helpers for ECEC661
# ----------------------------------------------------------------------------
# Usage examples:
#   make status
#   make push m="Update user_logic testbench"
#   make quick m="WIP" b=feature/lab4
#   make sync
#   make amend
#   make undo
# ============================================================================

SHELL    := /bin/bash
REMOTE   ?= origin
BRANCH   ?= $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null)
m        ?= Update
b        ?= $(BRANCH)

.DEFAULT_GOAL := help

.PHONY: help status diff log pull fetch sync add commit push quick amend undo \
        stash pop tag branch new-branch clean-branches

## Show this help message
help:
	@echo "Git workflow targets (current branch: $(BRANCH))"
	@echo ""
	@echo "  make status              Show working tree status"
	@echo "  make diff                Show unstaged diff"
	@echo "  make log                 Show recent commits (graph)"
	@echo "  make fetch               Fetch from $(REMOTE)"
	@echo "  make pull                Pull --rebase from $(REMOTE)/$(BRANCH)"
	@echo "  make sync                Fetch + pull --rebase"
	@echo ""
	@echo "  make add                 Stage all changes"
	@echo "  make commit m=\"msg\"      Commit staged changes"
	@echo "  make push   m=\"msg\"      Add + commit + push to $(REMOTE)/$(BRANCH)"
	@echo "  make quick  m=\"msg\" b=branch   Push to a specific branch"
	@echo "  make amend               Amend last commit (no message change)"
	@echo "  make undo                Undo last commit (keep changes staged)"
	@echo ""
	@echo "  make stash               Stash current changes"
	@echo "  make pop                 Pop most recent stash"
	@echo "  make tag v=vX.Y.Z        Create and push annotated tag"
	@echo "  make new-branch b=name   Create & switch to new branch"
	@echo "  make clean-branches      Delete merged local branches"

## Show working tree status
status:
	@git status

## Show unstaged diff
diff:
	@git diff --stat && echo "" && git diff

## Show recent commit graph
log:
	@git log --oneline --graph --decorate --all -n 20

## Fetch from remote
fetch:
	@git fetch $(REMOTE) --prune

## Pull --rebase current branch
pull:
	@git pull --rebase $(REMOTE) $(BRANCH)

## Fetch + rebase against upstream
sync: fetch pull

## Stage all changes
add:
	@git add -A
	@git status --short

## Commit staged changes with message `m`
commit:
	@if git diff --cached --quiet; then \
		echo "Nothing staged to commit."; \
	else \
		git commit -m "$(m)"; \
	fi

## Add + commit + push (one-shot) to current branch
push:
	@git add -A
	@if git diff --cached --quiet; then \
		echo "No changes to commit — pushing anyway."; \
	else \
		git commit -m "$(m)"; \
	fi
	@git push $(REMOTE) $(BRANCH)

## Add + commit + push to branch `b`
quick:
	@git add -A
	@if git diff --cached --quiet; then \
		echo "No changes to commit — pushing anyway."; \
	else \
		git commit -m "$(m)"; \
	fi
	@git push $(REMOTE) $(b)

## Amend last commit with currently staged changes (no edit)
amend:
	@git add -A
	@git commit --amend --no-edit
	@echo "Run 'git push --force-with-lease $(REMOTE) $(BRANCH)' if already pushed."

## Undo last commit but keep changes staged
undo:
	@git reset --soft HEAD~1
	@git status --short

## Stash working changes
stash:
	@git stash push -u -m "make-stash-$$(date +%Y%m%d-%H%M%S)"

## Pop most recent stash
pop:
	@git stash pop

## Create + push an annotated tag: `make tag v=v1.0.0`
tag:
	@if [ -z "$(v)" ]; then echo "Usage: make tag v=vX.Y.Z"; exit 1; fi
	@git tag -a $(v) -m "Release $(v)"
	@git push $(REMOTE) $(v)

## Create and switch to a new branch: `make new-branch b=feature/foo`
new-branch:
	@if [ -z "$(b)" ] || [ "$(b)" = "$(BRANCH)" ]; then \
		echo "Usage: make new-branch b=<new-branch-name>"; exit 1; \
	fi
	@git checkout -b $(b)

## Delete local branches already merged into main
clean-branches:
	@git branch --merged main | grep -vE '^\*|^\s*main$$' | xargs -r git branch -d
