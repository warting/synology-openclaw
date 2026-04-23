# synology-openclaw

Unofficial Synology DSM package that installs [OpenClaw](https://openclaw.ai) via Container Manager.

Install, upgrade, and uninstall from Package Center like any other DSM package.

## Install on DSM

1. DSM → **Package Center → Settings → General** → Trust Level: **Any publisher**.
2. **Package Center → Settings → Package Sources → Add**:
   - Name: `warting`
   - Location: `https://warting.github.io/synology-openclaw/`
3. **Community** tab → **OpenClaw** → **Install**.
4. The install wizard asks only for the web UI port (default `18789`). LLM providers (Anthropic, OpenAI, Ollama, LM Studio, …) are configured from inside OpenClaw's own UI after install.

Alternatively, download a `.spk` from [Releases](https://github.com/warting/synology-openclaw/releases) and use **Manual Install**.

## What the package does

- Runs the `ghcr.io/openclaw/openclaw` container under `docker compose`.
- Stores persistent data under `/volume1/docker/openclaw/`.
- Publishes the OpenClaw gateway on `<NAS_IP>:18789` (or the port you picked at install).
- Adds an OpenClaw icon to the DSM main menu.

### What it does NOT do

- **No network isolation.** The container runs on the NAS's default Docker bridge and can reach anything on your LAN. If you want VLAN-level isolation, configure that in your router/switch.
- **No Docker socket mount.** OpenClaw's built-in per-tool sandbox is intentionally left off (`OPENCLAW_SANDBOX=0`). Mounting `/var/run/docker.sock` into the container would be equivalent to giving it root on the NAS.

## Development

Requires `bash`, `tar`, `jq`, `shasum`/`sha256sum`.

```sh
./build.sh 0.1.0-0001          # builds build/openclaw-0.1.0-0001.spk
./build.sh 0.1.0-0001 2026.4.10  # also pin the OpenClaw image tag
```

Copy the `.spk` to your NAS and install via **Package Center → Manual Install** for testing.

Tag and push `v*.*.*` to trigger the release workflow:

```sh
git tag v0.1.0
git push --tags
```

GitHub Actions builds the `.spk`, creates a Release, regenerates `feed/packages.json`, and deploys the feed to GitHub Pages.

## Layout

```
src/            SPK source — scripts, INFO, wizard, compose file
feed/           GitHub Pages site: packages.json (the DSM feed) + landing page
build.sh        Local build script
feed.sh         Regenerates feed/packages.json from GitHub Releases
.github/        CI + release workflows
dev/            Dev helpers (test checklist, format checks)
```

## License

MIT. Unofficial — not affiliated with Synology or OpenClaw.
