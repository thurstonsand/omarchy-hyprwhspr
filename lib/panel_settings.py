"""The panel's settings file, provider table, and API keys, shared by bin/ scripts."""

import json
import os
from pathlib import Path

PLUGIN = Path(__file__).resolve().parent.parent
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))

SETTINGS = CONFIG_HOME / "hyprwhspr/panel.json"
HYPRWHSPR_CONFIG = CONFIG_HOME / "hyprwhspr/config.json"
SYSTEM_PROMPT_OVERRIDE = CONFIG_HOME / "hyprwhspr/system.md"
CLEANUP_LOG = STATE_HOME / "hyprwhspr/cleanup.jsonl"
# Transcripts live in tmpfs only, gone at logout.
RECENT = Path(os.environ["XDG_RUNTIME_DIR"]) / "hyprwhspr/recent.json"
SERVICE_PROCS = Path(
    f"/sys/fs/cgroup/user.slice/user-{os.getuid()}.slice/user@{os.getuid()}.service"
    "/app.slice/hyprwhspr.service/cgroup.procs"
)


def settings() -> dict:
    return json.loads(SETTINGS.read_text()) if SETTINGS.exists() else {}


def providers() -> dict:
    table = json.loads((PLUGIN / "share/providers.json").read_text())
    for name, overrides in settings().get("providers", {}).items():
        table[name] = {**table.get(name, {}), **overrides}
    return table


def vocabulary() -> list[str]:
    """Every word taught through hyprwhspr's word_overrides, misspellings excluded."""
    config = json.loads(HYPRWHSPR_CONFIG.read_text())
    # Upstream's default while the key is unset.
    overrides = config.get("word_overrides", {"hyper whisper": "hyprwhspr"})
    return sorted(set(overrides.values()), key=str.lower)


def system_prompt() -> str:
    path = SYSTEM_PROMPT_OVERRIDE
    if not path.exists():
        path = PLUGIN / "share/system.md"
    return path.read_text().strip()


def key_file(provider_id: str) -> Path:
    return CONFIG_HOME / "hyprwhspr/keys" / provider_id


def auth_headers(provider_id: str, provider: dict) -> dict:
    headers = {}
    if provider["protocol"] == "messages":
        headers["anthropic-version"] = "2023-06-01"
    if "key_env" in provider:
        key = api_key(provider["key_env"])
    elif key_file(provider_id).exists():
        key = key_file(provider_id).read_text().strip()
    else:
        return headers
    return {**headers, **key_header(provider["auth"], key)}


def key_header(auth: str, key: str) -> dict:
    if auth == "x-api-key":
        return {"x-api-key": key}
    return {"authorization": f"Bearer {key}"}


def api_key(name: str) -> str:
    """The hook inherits keys from the daemon; the panel borrows the daemon's."""
    if name in os.environ:
        return os.environ[name]
    prefix = f"{name}=".encode()
    for pid in SERVICE_PROCS.read_text().split():
        for entry in Path(f"/proc/{pid}/environ").read_bytes().split(b"\0"):
            if entry.startswith(prefix):
                return entry[len(prefix) :].decode()
    raise SystemExit(f"{name} is not set in the hyprwhspr service environment")
