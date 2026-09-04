---
name: bw-cli
description: 'Use when reading a secret out of the Bitwarden vault on this machine with the bw CLI — an SSH key, password, token, or note, especially when it has to land on disk. Also use when bw reports the vault is locked, or an interactive bw command dies with "ERR_USE_AFTER_CLOSE: readline was closed".'
---

# bw (Bitwarden CLI)

Vault access on this machine goes through the `bw` CLI. Two things go wrong:
the unlock prompt needs a TTY the agent does not have, and secrets leak into
the transcript the moment they touch stdout.

## Unlocking — you cannot do this yourself

`bw unlock` reads the master password through a hidden prompt that requires a
TTY. Bash tool calls and `!`-prefixed commands have none, so it dies with:

```
Error [ERR_USE_AFTER_CLOSE]: readline was closed
```

Ask the user to run this in a **real terminal window**, then continue:

```bash
bw unlock --raw > ~/.bw_session && chmod 600 ~/.bw_session
```

Keep the command on one line — a wrapped line breaks the `&& chmod`.

**Never:**
- Run `bw unlock` yourself, in any wrapper.
- Use `--passwordenv` or `--passwordfile`. They work non-interactively, but the
  master password ends up in the transcript or on disk.
- Ask the user to paste the session key into chat. It is a bearer token for the
  entire vault, and chat is permanent.

## Quick reference

| Task | Command |
| --- | --- |
| state | `bw status \| jq -r .status` → `locked` / `unlocked` |
| session | `export BW_SESSION=$(cat ~/.bw_session)` |
| refresh | `bw sync --session "$BW_SESSION"` |
| find | `bw list items --search TERM --session "$BW_SESSION" \| jq -r '.[] \| "\(.type)\t\(.id)\t\(.name)"'` |
| item types | 1=Login 2=Secure Note 3=Card 4=Identity 5=SSH key |
| SSH key fields | `.sshKey.privateKey` `.sshKey.publicKey` `.sshKey.keyFingerprint` |

## Getting a secret onto disk

The secret goes from `bw` into the file. It never reaches stdout, never lands
in a variable you echo, never enters the transcript.

```bash
umask 077
ITEM=$(bw get item "$ID" --session "$BW_SESSION")
printf '%s' "$ITEM" | jq -r '.sshKey.privateKey | sub("\n+$";"")' > "$PRIV"
printf '%s' "$ITEM" | jq -r '.sshKey.publicKey  | sub("\n+$";"")' > "$PRIV.pub"
chmod 600 "$PRIV"
chmod 644 "$PRIV.pub"
```

`sub("\n+$";"")` normalises the trailing newline: `jq -r` appends exactly one,
and OpenSSH wants exactly one. Refuse to overwrite an existing key file — check
first and stop rather than clobbering something you cannot restore.

To inspect an item, project metadata only — never the secret itself:

```bash
bw get item "$ID" --session "$BW_SESSION" |
  jq '{name, publicKey: .sshKey.publicKey, privKeyLen: (.sshKey.privateKey|length)}'
```

## Verify before trusting

```bash
ssh-keygen -y -f "$PRIV" < /dev/null   # derived pubkey must equal what you wrote
ssh-keygen -lf "$PRIV.pub"             # fingerprint must equal the vault's keyFingerprint
```

For a git signing key, prove the whole chain end to end:

```bash
ssh-keygen -Y sign -f "$PRIV" -n git FILE
ssh-keygen -Y verify -f ~/.config/git/allowed_signers -I EMAIL -n git -s FILE.sig < FILE
```

`Good "git" signature` is the only acceptable result.

## Clean up

```bash
rm -f ~/.bw_session
bw lock
```

Do this as soon as the task is done. A stale session file leaves the vault
reachable without the master password.

## Common mistakes

| Mistake | What happens |
| --- | --- |
| `bw unlock` from a tool call or `!` | `ERR_USE_AFTER_CLOSE` — no TTY |
| `--passwordenv` / `--passwordfile` | master password in transcript or on disk |
| `cat` the private key to check it | secret in the transcript, permanently |
| no `umask 077` before the redirect | key briefly world-readable |
| leaving `~/.bw_session` behind | vault stays open without the master password |
| multiline `for` / `while … done` in a tool call | zsh `parse error near 'done'` — put it in a script file or use `xargs` |

## Bitwarden MCP server

`@bitwarden/mcp-server` is official and unlocks via a native OS dialog, which
avoids the TTY problem. It is deliberately not used here: `get` returns the item
through the protocol and into the model's context, so a private key would land
in the transcript — the exact thing this skill exists to prevent. Consider it
only for non-secret lookups.
