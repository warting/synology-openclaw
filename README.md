# synology-openclaw

Run [OpenClaw](https://openclaw.ai) on a Synology NAS via Container Manager, with sensible security defaults.

## Install via Container Manager (recommended)

Takes about 2 minutes.

1. On DSM, open **Package Center** and confirm **Container Manager** is installed. If not, install it (free, published by Synology).
2. Open **Container Manager → Project → Create**.
3. Fill in:
   - **Project name**: `openclaw`
   - **Path**: click to browse, pick the `docker` shared folder and put the project under `docker/openclaw` (DSM will create that folder if it doesn't exist)
   - **Source**: *Create docker-compose.yml* — paste the content of [`compose.yml`](compose.yml) from this repo into the editor
4. Click **Next** → review → **Done**. Container Manager pulls the image and starts the container.
5. Wait ~30 seconds for the first start, then browse to `http://<your-nas-ip>:18789/`.
6. OpenClaw's onboarding screen appears. Configure your LLM provider(s) (Anthropic, OpenAI, Ollama, LM Studio, …) there — that's where credentials and model selection live.

### What you get

- OpenClaw running as a restart-policy container, listening on port `18789`.
- Persistent data in `/volume1/docker/openclaw/config` and `…/workspace`. Those dirs survive upgrades; back them up with Hyper Backup if you care about your chat history.
- **No Docker socket mounted** — OpenClaw's per-tool sandbox stays off. Mounting the socket would be equivalent to giving the container root on the NAS, which defeats the containment point.
- **Same-LAN networking** — no VLAN isolation. The container can reach any device on your LAN. If you want strict network isolation, configure a VLAN + firewall rules in your UniFi controller; that's a router concern, not a container concern.

### Upgrading

Container Manager → Project → `openclaw` → **Action → Pull and rebuild**. Or, from SSH:

```sh
cd /volume1/docker/openclaw
sudo docker compose pull
sudo docker compose up -d
```

### Changing the host port

If 18789 conflicts with something else, edit the Project's compose file (Container Manager → Project → openclaw → Edit) and change `18789:18789` to `<other-port>:18789`, then rebuild.

## Why not a Synology .spk package?

Tried. DSM 7.2's unsigned-package validator treats `run-as: package` configs as "Invalid file format" at upload time, while refusing to install anything that declares `run-as: root`. SynoCommunity packages work around this by being signed against a trusted publisher key — not something a personal repo can do without either Synology's development token (requires Synology support ticket) or wider distribution infrastructure.

Leaving the SPK scaffolding in [`src/`](src/) and [`build.sh`](build.sh) for future use — if the situation changes (dev token obtained, or we're OK with users adding a custom GPG key to DSM's trust list) it's already built.

## Development (SPK, currently blocked)

Build the `.spk` locally:

```sh
./build.sh 0.1.0-0001
# produces build/openclaw-0.1.0-0001.spk
```

The package structure matches Synology's documented schema, but the upload validator in DSM 7.2 rejects unsigned third-party packages that try to run as anything other than root, and refuses to install root packages unless signed. See the [Synology developer guide on privileges](https://help.synology.com/developer-guide/privilege/preface.html).

Tag and push `v*.*.*` to trigger the release workflow anyway — it'll build and publish a `.spk`, and regenerate the [feed](https://warting.github.io/synology-openclaw/) on GitHub Pages. Once signing is sorted, those artifacts become installable as-is.

## License

MIT. Unofficial — not affiliated with Synology or OpenClaw.
