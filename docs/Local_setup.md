# Local Setup

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Python | 3.11+ | [python.org](https://python.org) |
| UV | latest | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Azure CLI (`az`) | latest | [learn.microsoft.com/cli/azure](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| Azure Developer CLI (`azd`) | latest, + `microsoft.foundry` extension | `curl -fsSL https://aka.ms/install-azd.sh \| bash` then `azd ext install microsoft.foundry` |

This repo is a sibling of the other Redwood repos (see the platform-level
`redwood-ai-insurance/docs/Local_setup.md`), but has no dependency on Docker
Compose or the other repos — it talks to Azure directly.

## Install dependencies

```bash
uv sync --all-extras
```

`agent-framework-core`/`agent-framework-azure-ai`/`azure-ai-projects` are
public-preview packages; `uv.tool.prerelease = "allow"` in `pyproject.toml`
lets `uv` resolve prerelease versions. Record the resolved versions in this
repo's `Readme.md` once pinned.

## Environment

```bash
cp example.env .env
# fill in AZURE_* values from your Foundry project / Search / OpenAI resources
az login
```

Every value in `.env` is required — `config/settings.py` reads with
`os.environ["KEY"]` (no defaults) and fails fast on anything missing, per the
platform's config convention.

## Run tests (no Azure credentials needed)

```bash
uv run pytest
```

`tests/test_agent_local.py` exercises the agent-wiring logic against fakes in
`tests/fakes/` — no network calls, no `.env` required.

## Provision + deploy (real Azure subscription required)

See `docs/PHASE_1_POLICY_QA_AGENT.md` for the full provisioning order and
`hosted_agent/README.md` for the `azd ai agent init` / `azd up` deployment
steps. These create real, billable Azure resources — run them deliberately,
one at a time.
