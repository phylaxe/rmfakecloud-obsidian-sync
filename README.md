# rmfakecloud → Obsidian Sync

Scheduled container that pulls reMarkable notes from a self-hosted rmfakecloud
via `rmapi`, converts `.rm` vector drawings to Excalidraw Markdown using
[`remarkable-obsidian-sync`](https://github.com/EelcovanVeldhuizen/remarkable-obsidian-sync),
and pushes them to an Obsidian vault Git repository.

## Flow

```
reMarkable ↔ rmfakecloud ── rmapi mget ──▶ *.rmdoc (ZIP)
                                             │ unzip
                                             ▼
                                        xochitl layout
                                             │ remarkable-obsidian-sync
                                             ▼
                                     .excalidraw.md files
                                             │ git commit + push
                                             ▼
                                     GitHub obsidian vault
```

## Required environment variables

| Var | Example |
|---|---|
| `RMAPI_HOST` | `https://remarkable.opipomio.ch` |
| `VAULT_REPO_URL` | `git@github.com:phylaxe/obsidian_vault.git` |
| `RMAPI_AUTH_B64` | base64 of a seeded `~/.rmapi` token file (first-run bootstrap) |
| `SSH_DEPLOY_KEY_B64` | base64 of the Ed25519 private deploy key |

Optional: `VAULT_SUBDIR` (default `reMarkable`), `VAULT_BRANCH` (default `main`),
`GIT_USER_EMAIL`, `GIT_USER_NAME`.

## Persistent volumes

- `/state/rmapi` — rmapi refresh token (seeded from `RMAPI_AUTH_B64` on first run, refreshed afterwards)
- `/state/vault` — git checkout (avoids full re-clone each run)
