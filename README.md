# docker-configs

This repo contains the Compose files for the services I run and the Komodo configuration that deploys them. Service files are in `services/`, Komodo stacks are in `komodo/`, and `setup/` has scripts for preparing a new machine.

## Making changes

To change a service, edit its files, commit, and push to `main`. Then run the Resource Sync in Komodo, unless the GitHub webhook is set up to run it automatically. Komodo will update the stack on the server assigned to it in `komodo/stacks/`. You normally don’t need to create stacks in the UI.

Passwords, API keys, and connection strings containing credentials belong in Infisical. Non-secret settings shared by every machine can go in the repo. Settings for one machine, such as `HOST_PORT` or `GIT_REF`, go in that stack’s Environment box in Komodo.

Be careful with the Environment box: if you put anything in it, Komodo replaces the entire `.env` file in the stack’s run directory. If you leave it empty, Komodo leaves the file alone. Redlib keeps its shared settings in `.env.defaults` for this reason.

## Setting up Core

Core runs Komodo and manages the other machines. These steps are for a new Core machine; you only need to do them once.

First, create a project in Infisical with a `prod` environment and add the secrets listed [below](#secrets). Services use folders named after their directories, so `services/litellm` reads from `/litellm`. In MongoDB Atlas, allow the Core machine’s IP. Keep the Atlas URI in Infisical, not in the repo.

Clone this repo on the Core machine and run the setup script:

```bash
git clone git@github.com:Cyanistic/docker-configs.git
cd docker-configs
sudo ./setup/core/setup-core.sh
```

The first run creates `/etc/secret-run/infisical.env`. Add `INFISICAL_PROJECT_ID` and either `INFISICAL_CLIENT_ID` and `INFISICAL_CLIENT_SECRET`, or a token. Then run the script again.

Set `KOMODO_HOST` and the other non-secret settings in `services/komodo-core/compose.env`, which the script copies from the example file. Open Core at `http://<this-host>:9120`, or at the address you set with `KOMODO_HOST`. The initial username is in the example file and the password is in Infisical. Log in and change the admin password.

In Komodo, create an onboarding key for adding machines. This is a one-time invitation, not an Infisical secret or an API token. Also create a Resource Sync pointing at this repo, branch `main`, path `komodo`, and execute it. You can add a GitHub webhook later if you want pushes to run the sync automatically.

### Secrets

Use these folders in the Infisical `prod` environment:

| Folder | Values |
| --- | --- |
| `/komodo-core` | `KOMODO_DATABASE_URI` (the Atlas `mongodb+srv://...` URI), `KOMODO_JWT_SECRET`, `KOMODO_WEBHOOK_SECRET`, `KOMODO_INIT_ADMIN_PASSWORD` |
| `/litellm` | `LITELLM_MASTER_KEY`, `LITELLM_SALT_KEY`, `DATABASE_URL`, provider keys |
| `/model-hotel` | `MASTER_KEY`, `DATABASE_URL` |
| `/librechat` | `MONGO_URI`, `CREDS_KEY`, and any other values used by the Compose override |
| `/pangolin` | `SERVER_SECRET` |
| `/newt` | `NEWT_ID`, `NEWT_SECRET` |
| `/shitter` | `SESSIONS_JSONL`, `HMAC_KEY` |

Generate `SERVER_SECRET` and `HMAC_KEY` with `openssl rand -hex 32`. Don’t change Pangolin’s `SERVER_SECRET` later without using `pangctl rotate-server-secret`.

`SESSIONS_JSONL` is the full content of a `sessions.jsonl` file from a burner Twitter login, with one JSON object per line. Shitter renders that file and `nitter.conf` from Infisical when it starts. Neither rendered file should go in the repo.

## Adding a machine

Run the Periphery setup script on each machine that should run services. You can also run it on the Core machine if you want Core to manage itself:

```bash
sudo ./setup/periphery/setup-periphery.sh \
  --core-address 'wss://komodo.cyanistic.com' \
  --onboarding-key '<key from the Komodo UI>' \
  --connect-as production
```

`production` is the machine’s name in Komodo. The existing stacks target that name, so use it for the main VPS and for a replacement VPS if you move providers. Machine IPs don’t go in the stack files. Discard the onboarding key after the machine joins.

If you’re adding a separate machine that should keep its own name, use something like `home` or `gpu` instead. Change the `server` setting only for stacks that should run there.

## Pangolin and Newt

Pangolin handles the public addresses. Newt connects machines running services to Pangolin. They can run on the same machine.

1. Put `SERVER_SECRET` in Infisical `/pangolin`, set the Let’s Encrypt email in `config/traefik/traefik_config.yml`, and deploy Pangolin.
2. Create a site named `production` in Pangolin. Copy its `NEWT_ID` and `NEWT_SECRET` into Infisical `/newt`.
3. Deploy Newt.
4. Apply `services/pangolin/blueprint.yaml` under **Settings > Blueprints** in Pangolin, or use its CLI/API. The blueprint creates the public addresses for the services.

Point these DNS names at the Pangolin machine:

| Address | Service | Host port |
| --- | --- | --- |
| `pangolin.cyanistic.com` | Pangolin dashboard, through Traefik rather than the blueprint | 80/443 |
| `redlib.cyanistic.com` | redlib | 6971 |
| `llm.cyanistic.com` | model-hotel | 4006 |
| `komodo.cyanistic.com` | Komodo Core | 9120 |

LiteLLM is not exposed publicly.

## Services

- `services/shitter` is a Nitter fork. It renders `nitter.conf` and `sessions.jsonl` from Infisical `/shitter` when it starts. The config template is `nitter.conf.template`.
- `services/redlib` keeps its instance settings in `.env.defaults` and doesn’t use the secrets wrapper.
- `services/litellm` reads its secrets from Infisical `/litellm`.
- `services/model-hotel` builds from source at `GIT_REF`, which defaults to `v0.9.99`. Force a rebuild after changing the ref.
- `services/librechat` uses upstream Compose with our override and reads secrets from `/librechat`.
- `services/pangolin` serves `cyanistic.com`; its public routes are in `blueprint.yaml`.
- `services/newt` is the tunnel client and reads its credentials from `/newt`.
- `services/komodo-core` is started by `setup-core.sh`, not by Resource Sync.

Deploy from `main`. The old `redlib`, `litellm`, `model-hotel`, and `librechat` branches are leftovers.
