# docker-configs

This repo is the server. Clone it, bootstrap Core, attach machines, then live in git.

You almost never click "New Stack" after the first day. Edit a file, commit, push. Komodo deploys it.

```
services/   how each app runs (Compose)
setup/      turn a blank Linux VM into a managed box
komodo/     what those boxes should run
```

## First time (Core)

Do this once, on the machine that will run Komodo.

1. In Infisical (one project, env `prod`), make a folder per service dir and put the secrets there. Folder name = last part of the path (`services/litellm` -> `/litellm`).

   | Folder | At least |
   | --- | --- |
   | `/komodo-core` | `KOMODO_DATABASE_URI` (Atlas `mongodb+srv://...`), `KOMODO_JWT_SECRET`, `KOMODO_WEBHOOK_SECRET`, `KOMODO_INIT_ADMIN_PASSWORD` |
   | `/litellm` | `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `DATABASE_URL`, provider keys |
   | `/model-hotel` | `MASTER_KEY`, `DATABASE_URL` |
   | `/librechat` | `MONGO_URI`, `CREDS_KEY`, and whatever the override interpolates |
   | `/pangolin` | `SERVER_SECRET` (`openssl rand -hex 32`, then leave it) |
   | `/newt` | `NEWT_ID`, `NEWT_SECRET` (from the Pangolin site you create) |

   In Atlas: allow this machine's IP. The URI stays in Infisical, not in git.

2. Clone and bootstrap:

   ```bash
   git clone git@github.com:Cyanistic/docker-configs.git
   cd docker-configs
   sudo ./setup/core/setup-core.sh
   ```

   First run writes `/etc/secret-run/infisical.env`. Fill in a machine identity (`INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET`) or a token, plus `INFISICAL_PROJECT_ID`. Re-run the script.

   Also edit `services/komodo-core/compose.env` (copied from the example): `KOMODO_HOST` and the non-secret knobs.

3. Open Core (`http://<this-host>:9120`, or whatever `KOMODO_HOST` is). Log in (username is in the example file; password is in Infisical). Change the admin password.

4. Create an **onboarding key** in the UI. That is a one-time invite, not an Infisical secret and not an API token. Whoever shows up with it becomes a Server.

5. Create one **Resource Sync**: this repo, branch `main`, path `komodo`. Execute it. Optionally add a GitHub webhook later so push deploys without clicking Execute.

## Add a machine

On every box that should run apps (including the Core host, if Core should manage itself):

```bash
sudo ./setup/periphery/setup-periphery.sh \
  --core-address 'wss://komodo.cyanistic.com' \
  --onboarding-key '<the key from the UI>' \
  --connect-as production
```

`--connect-as` is the Server **name** inside Komodo. Stacks in `komodo/stacks` all say `server = "production"`. Use that name for the main VPS, and for the next VPS when you move providers. You do not put an IP in git. After the handshake, throw the key away.

A second machine that should stay distinct gets a different name (`home`, `gpu`, …). Only the stacks that should run there change `server =`.

## Pangolin and Newt

Pangolin is the front door (`pangolin.cyanistic.com`). Newt is the tunnel on every box that runs apps. Same machine can run both.

1. Put `SERVER_SECRET` in Infisical `/pangolin` (`openssl rand -hex 32`). Do not change it later without `pangctl rotate-server-secret`. Fill the Let's Encrypt email in `config/traefik/traefik_config.yml`. Deploy the Pangolin stack.
2. In the Pangolin UI, create a **site** named `production`. Copy `NEWT_ID` / `NEWT_SECRET` into Infisical `/newt`.
3. Deploy the Newt stack. It only opens the tunnel.
4. Paste `services/pangolin/blueprint.yaml` into Pangolin (**Settings > Blueprints**), or apply it with the CLI/API. That file is what creates the public names.

| Public name | App | Host port |
| --- | --- | --- |
| `pangolin.cyanistic.com` | Pangolin dashboard (Traefik, not the blueprint) | 80/443 |
| `redlib.cyanistic.com` | redlib | 6971 |
| `llm.cyanistic.com` | model-hotel | 4006 |
| `komodo.cyanistic.com` | Komodo Core | 9120 |

LiteLLM is not on the internet. Point those DNS names at the Pangolin box.

## Day to day

- Change a compose file or a `komodo/stacks/*.toml`, commit, push `main`.
- Core diffs the sync. Execute (or let the GitHub webhook do it).
- Periphery on that Server runs compose. Stacks that need secrets go through `secret-run`, which opens the Infisical folder named after the service directory.

**Where a value lives**

- Secret (password, API key, URI with creds) -> Infisical.
- Same on every box, not a secret -> git (compose or `.env.defaults`).
- This box only (`HOST_PORT`, `GIT_REF`, extra CORS) -> that stack's Environment box in Komodo.

Komodo writes the Environment box to `.env` in the run directory. If the box is empty, it leaves the file alone. If you type anything, it **replaces** the whole file. That is why redlib's catalog is `.env.defaults`, not `.env`.

## Apps

| Dir | Notes |
| --- | --- |
| `services/redlib` | Instance config in `.env.defaults`. No secrets wrapper. |
| `services/litellm` | Secrets from Infisical `/litellm`. |
| `services/model-hotel` | Builds from source at `GIT_REF` (default `v0.9.99`). Force a rebuild after a bump. |
| `services/librechat` | Upstream compose + our override. Secrets from `/librechat`. |
| `services/pangolin` | Front door. Domain is `cyanistic.com`. Blueprint in `blueprint.yaml`. |
| `services/newt` | Tunnel client. Secrets from Infisical `/newt`. |
| `services/komodo-core` | Core only. Started by `setup-core.sh`, not by Resource Sync. |

Old per-service branches (`redlib`, `litellm`, `model-hotel`, `librechat`) are leftovers. Deploy from `main`.
