# Kombine skills

Agent skills for [Kombine](https://kombine.dev), the minimalist Pomodoro + task app. They let Claude Code, Cursor, Codex and other agents read and manage your Kombine account through the [API](https://kombine.dev/docs/power-users/api/).

| Skill | What it does |
|---|---|
| `kombine` | Tasks, focus sessions, activities, goals, timer and stats: "what's due today?", "add a task", "log 45 min on the importer", "how's my streak?" |
| `jira-to-kombine` | Imports your open Jira issues as Kombine tasks, skipping ones already imported |

## 1. Create a token

At [app.kombine.dev](https://app.kombine.dev) go to **Settings › Account › Personal access tokens** and create one with only the permissions you need ([docs](https://kombine.dev/docs/power-users/access-tokens/)). Then add it to your shell profile:

```bash
export KOMBINE_TOKEN='kmb_pat_…'
```

Restart your agent so it picks up the variable. Don't paste the token into a chat.

## 2. Install

**Claude Code** (plugin, updates with `/plugin marketplace update kombine`):

```
/plugin marketplace add AdamCodingCorner/kombine-skills
/plugin install kombine@kombine
```

**Any agent** ([skills CLI](https://github.com/vercel-labs/skills): Claude Code, Cursor, Codex, Copilot, …):

```bash
npx skills add AdamCodingCorner/kombine-skills          # pick skills and agents interactively
npx skills add AdamCodingCorner/kombine-skills -g -a claude-code   # all skills, globally, for Claude Code
npx skills update                                       # later
```

**Manually:** copy a folder from `skills/` into your agent's skills directory (e.g. `~/.claude/skills/`).

## Requirements

`curl` and `jq`. `jira-to-kombine` also needs `uuidgen` and Jira credentials (see its [SKILL.md](skills/jira-to-kombine/SKILL.md)).

## License

MIT
