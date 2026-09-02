---
name: herdr-worktree-handoff
description: Use when the user asks to hand a task off to another Claude Code agent in its own git worktree that they can watch from Herdr — "別 worktree に切り出して", "herdr で動かして", "spawn a worktree agent", "delegate this to a new session in herdr". Also use when `herdr agent start` returns agent_not_ready, or `herdr agent prompt --wait` comes back blocked. Also use when the delegated work is done and the user wants the Herdr workspace, worktree, and branch removed (「片付けて」「消して」, "clean up the worktree").
---

# Handing a task off to a Herdr worktree agent

`wt` (worktrunk) owns worktrees on this machine; Herdr owns workspaces and
agents. Use them in that order. Skip the discovery pass — the recipe below is
the whole thing, verified on wt 0.72 / herdr 0.8 / claude 2.1.

## Precondition

```bash
test "${HERDR_ENV:-}" = 1
```

Not inside Herdr? Run `claude --bg -n <name>` from the worktree instead and
coordinate with `ListAgents` / `SendMessage`.

## Recipe

```bash
# 1. worktree via wt. First stdout line is JSON; use its .path
wt -C <repo> switch --create <branch> --no-cd --format json

# 2. workspace on that path, without stealing the user's focus
herdr workspace create --cwd <path> --label <branch> --no-focus   # → .result.root_pane.pane_id

# 3. claude in that pane; everything after -- goes to claude
herdr agent start <branch> --kind claude --pane <pane_id> --timeout 60000 -- --permission-mode acceptEdits -n <branch>

# 4. clear the trust dialog (below), then hand over the task
herdr agent prompt <branch> "<task>" --wait --timeout 600000       # returns on idle | done | blocked

# 5. read what the worker said
herdr agent read <branch> --source recent-unwrapped --lines 60
```

Agent name = branch name; it must match `[a-z][a-z0-9_-]{0,31}`.

Never `herdr worktree create`: it ignores wt's path template and hooks, puts
the checkout under `~/.herdr/worktrees/`, and opens a stray second workspace
at the repo root.

## Task wording

Give the worker the worktree path and branch, say whether to commit (default:
no — the user inspects first), and ask it to finish with a one-line summary.

## The two blocked states

**`agent start` → `agent_not_ready`.** Usually Claude Code's folder-trust
dialog on a path it has not seen. Read before touching keys:

```bash
herdr agent read <name> --source visible --lines 30
```

If the pane shows "Is this a project you created or one you trust?", the
repo is one the user asked you to work in — answer it:

```bash
herdr agent send-keys <name> down && herdr agent send-keys <name> enter
herdr agent read <name> --source visible --lines 20     # confirm the dialog is gone
herdr agent wait <name> --until idle --timeout 60000
```

Anything else on screen: report it to the user. Never send keys into a pane
you have not read — when `agent start` returns `idle`, the same keystrokes
land in the worker's input box.

**`agent prompt --wait` → `blocked`.** The worker hit a tool permission
prompt (acceptEdits does not cover Bash). `agent read` the pane and tell the
user what it is waiting for; they answer it from the Herdr sidebar. Do not
answer permission prompts on the worker's behalf.

After any `send-keys`, `agent wait` can return the stale pre-keypress state
immediately. `agent read` first, then wait again.

## Reporting and cleanup

Report branch, worktree path, workspace id, agent name, and the worker's
final message. Leave the workspace open — the user wants to inspect it.

When they say it is done, remove all three, in this order:

```bash
herdr workspace list                    # label == branch → workspace_id
herdr workspace close <workspace_id>    # first: this also ends the worker's claude
wt -C <repo> remove <branch> --foreground   # removes the worktree; deletes the branch too when it is merged
#   -D  branch is unmerged and the user said to drop it
#   -f  worktree has uncommitted changes and the user said to drop them
git -C <repo> worktree list && git -C <repo> branch    # confirm both are gone
```

`-D` and `-f` are irreversible. Add them only when the user said the branch
or the changes can go; otherwise stop at the `wt remove` error and ask.
