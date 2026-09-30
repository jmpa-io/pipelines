# claude-config

Personal Claude Code config and standards for [jmpa-io](https://github.com/jmpa-io) repos.

This repo is the personal equivalent of CBA's `photon-ai-config` — it gives Claude consistent context and guardrails when working in jmpa-io repositories.

## What's in here

- `CLAUDE.md` — standards, conventions, and behaviour rules loaded by Claude Code in every repo that includes this config
- `skills/` — personal Claude Code skills (slash commands) for jmpa-io workflows

## Adding to a repo

```bash
cd ~/go/src/github.com/jmpa-io/<repo>

# Add as submodule
git submodule add git@github.com:jmpa-io/claude-config.git .claude/config

# Symlink CLAUDE.md so Claude Code picks it up
ln -sf config/CLAUDE.md .claude/CLAUDE.md

git add .gitmodules .claude/
git commit -m "chore: add jmpa-io/claude-config as Claude Code config submodule"
git push origin main
```

## Updating the submodule in a repo

```bash
cd .claude/config
git pull origin main
cd ../..
git add .claude/config
git commit -m "chore: update claude-config submodule"
git push origin main
```

## Adding skills

Drop `.md` skill files into `skills/`. They follow the same format as `~/.claude/agents/*.md`.
