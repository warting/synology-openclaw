# Manual test checklist (on a real Synology NAS, DSM 7.2+)

Run through this end-to-end after changes that affect install/start/stop/uninstall behavior.

## 0. Prereqs

- [ ] DSM 7.2+ with **Container Manager** installed
- [ ] SSH enabled (Control Panel → Terminal & SNMP)
- [ ] "Trust Level: Any publisher" set (Package Center → Settings → General)

## 1. Build

```sh
./build.sh 0.0.0-testN
```

Expect `build/openclaw-0.0.0-testN.spk` + a printout with size + sha256.

## 2. Manual Install

- [ ] Package Center → Manual Install → upload the .spk
- [ ] Wizard shows two steps: UI port, optional Ollama
- [ ] Test both flows: (a) no Ollama, (b) Ollama host entered

## 3. Post-install state

```sh
ssh admin@<nas>
sudo docker ps --filter name=openclaw         # expect: Up
sudo cat /volume1/docker/openclaw/.env        # expect: UI_PORT + (optional) OLLAMA_BASE_URL
sudo cat /var/log/packages/openclaw.log       # scan for errors
```

- [ ] Browser → `http://<nas>:<ui_port>/` loads the OpenClaw UI
- [ ] DSM desktop → OpenClaw icon → opens UI in new tab

## 4. Ollama-less install sanity

```sh
sudo docker exec openclaw env | grep -i ollama     # expect: (empty)
```

## 5. Lifecycle

- [ ] Package Center → OpenClaw → Stop → `docker ps` shows nothing
- [ ] Start → container is back
- [ ] Reboot NAS → container auto-starts (restart: unless-stopped)

## 6. Uninstall

- [ ] Uninstall with "Remove data" UNCHECKED → `/volume1/docker/openclaw/` still present
- [ ] Reinstall → picks up existing `.env`/workspace (state preserved)
- [ ] Uninstall with "Remove data" CHECKED → directory is gone

## 7. Upgrade (once a feed is live)

- [ ] Add feed as Package Source
- [ ] Community tab → OpenClaw listed at current version
- [ ] Push a higher-version tag → wait for Actions → DSM shows "Update"
- [ ] Update → wizard is skipped; `.env` survives; new image is running
