# jmpa-io Claude Code Config

## Identity

- Personal repos under jmpa-io — owned by Jordan Cleal
- Repo root: `~/go/src/github.com/jmpa-io/`
- Personal GitHub account (`jcleal`) must be active for pushes — not CBA
- GitHub org: `jmpa-io`

## Working Standards

- Push directly to `main` for small fixes; use a branch for larger changes — no PR required
- No Golden Pipeline, no DHP, no CBA-specific tooling
- Go is the primary language — follow standard Go conventions
- Keep it minimal: no over-engineering, no colour/reporting bash targets, no unnecessary abstractions
- Be direct and honest — don't say "done" if something failed
- Don't add features beyond what the task requires
- No comments unless the WHY is non-obvious

## Repo Conventions

- Makefiles are simple: targets call `go build` / `go test` / `docker build` directly
- No husky, no complex npm tooling in Go repos
- Dockerfiles use multi-stage builds where appropriate
- Personal repos push to GitHub Container Registry (`ghcr.io/jmpa-io/*`)
- Binaries are named after the repo

## Claude Behaviour

- No need to ask for approval before `git push` to `main` on personal repos
- GitHub Issues are used for tracking work instead of Jira
- Open an issue at the start of any significant task, close it when done
- Prefer editing existing files to creating new ones
- No inline comments unless the WHY is non-obvious
- No multi-paragraph docstrings or comment blocks

## MCP Context

- MCPs are in `~/go/src/github.com/jmpa-io/mcps`
- Atlassian MCP is available for personal tracking only — not CBA Jira
- GitHub MCP is NOT used — `gh` CLI is preferred for all GitHub operations

## Account Check

Before any git push or gh operation, verify the active account is `jcleal`:

```
gh auth status
```

If `Jordan-Cleal_cba` is active, switch with:

```
gh auth switch --user jcleal
```
