---
name: yadm-dotfiles
description: Manage this machine's dotfiles, which are version-controlled with yadm (not plain git). Use whenever committing, pushing, diffing, staging, or inspecting home-directory config files (e.g. ~/.pi, ~/.config, shell rc files, editor config). Enforces yadm over git and an English gitmoji commit-message convention.
---

# yadm dotfiles

Home-directory config files are tracked by **yadm**, backed by
`github.com/taiki-kuraishi/dotfiles`.

## Rules

- **Never use `git` for these files.** `git` in `$HOME` targets the wrong (or no)
  repo. Always use `yadm` for status / diff / add / commit / push / log.
- Only touch files that are already tracked unless the user asks to add new ones.
  Check with `yadm ls-files`.
- Commit messages: **English**, imperative, prefixed with a **gitmoji**, in the
  form `<emoji> <scope>: <summary>` (e.g. `✨ pi: add statusline extension`).
  Match the existing style — run `yadm log --oneline -20` first and mirror it.

## Workflow

```bash
yadm status                 # what changed
yadm diff                   # inspect unstaged changes
yadm diff --stat            # summary
yadm log --oneline -20      # study past commit-message style before writing one
```

Commit and push:

```bash
yadm add <paths>            # stage specific files (avoid blanket `yadm add -u` unless asked)
yadm commit -m "<emoji> <scope>: <summary>"
yadm push
```

- Prefer staging explicit paths over everything, so unrelated pending changes are
  not swept into the commit.
- If several unrelated changes are pending, ask whether to split them into
  separate commits.

## Gitmoji quick reference

| emoji | when |
| ------- | ------ |
| ✨ | new feature / add config or tool |
| 🔧 | tweak / change existing config |
| 🐛 | fix a bug |
| ♻️ | refactor without behavior change |
| 🗑️ | remove files or config |
| 📝 | docs / comments |
| ⬆️ / ⬇️ | bump deps up / down |
| 🎨 | formatting / structure only |

Pick the emoji that matches the dominant change. Full list: <https://gitmoji.dev>
