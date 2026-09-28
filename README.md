# m365-sim

Drop-in Microsoft Graph API mock server for testing. Returns realistic JSON fixtures for 50+ endpoints across 3 cloud targets and 3 scenarios.

## Use This Instead of Real M365

Point your Graph API client at `http://localhost:8888` instead of `https://graph.microsoft.com`. That's it.

### What to Change in Your Project

1. **Base URL**: Replace `https://graph.microsoft.com` with `http://localhost:8888`
2. **Auth token**: Use any string — `Bearer test` works. The server accepts any Bearer token without validation.
3. **No other changes needed.** Responses match real Graph API shapes exactly (`@odata.context`, `value` arrays, singleton objects).

### Start the Server

Requires [uv](https://docs.astral.sh/uv/) 0.12.2 or newer (`uv self update` to upgrade). uv installs the right Python (3.14 by default) for you.

```bash
# Clone and run
cd ~/github/m365-sim
uv sync                          # create .venv from uv.lock
uv run server.py --port 8888

# Or with Docker
docker build -t m365-sim .
docker run -d -p 8888:8888 m365-sim
```

Without uv, plain pip still works with any Python 3.11+: `pip install -r requirements.txt && python server.py --port 8888`. That file holds runtime dependencies only and is generated from `uv.lock`.

### Pick Your Scenario

| Flag | What You Get |
|------|-------------|
| `--scenario greenfield` | Fresh tenant, zero controls (default) |
| `--scenario hardened` | Full CMMC posture: 8 CA policies, FIDO2, compliant devices |
| `--scenario partial` | Mid-deployment: 3 CA policies, partial auth |
| `--cloud gcc-moderate` | `graph.microsoft.com`, Contoso Defense LLC (default) |
| `--cloud gcc-high` | `graph.microsoft.us`, Contoso Defense Federal LLC |
| `--cloud commercial-e5` | `graph.microsoft.com`, Contoso Corp |

```bash
uv run server.py --scenario hardened --cloud gcc-high --port 8888
```

### Quick Test

```bash
# Health check (no auth)
curl http://localhost:8888/health

# Get users
curl -H "Authorization: Bearer test" http://localhost:8888/v1.0/users

# Get users via beta API
curl -H "Authorization: Bearer test" http://localhost:8888/beta/users

# Filter
curl -H "Authorization: Bearer test" "http://localhost:8888/v1.0/users?\$filter=userType eq 'Member'"

# Simulate throttling
curl -H "Authorization: Bearer test" "http://localhost:8888/v1.0/users?mock_status=429"
```

### Stateful Mode (Deploy-Then-Verify)

```bash
uv run server.py --stateful --port 8888
```

POST/PATCH now mutate state. `POST /v1.0/_reset` restores baseline.

## Development

Dependencies live in `pyproject.toml` and are locked in `uv.lock`. Runtime packages are in `[project].dependencies`; test tools (pytest, httpx) are in the `dev` dependency group, which `uv sync` installs by default.

```bash
uv run pytest tests/ -v                 # full suite (starts real server subprocesses)
uv run --isolated --python 3.11 pytest tests/   # another supported Python; leaves .venv alone

uv add <package>                        # add a runtime dependency
uv add --dev <package>                  # add a test-only dependency
uv export --locked --no-dev -o requirements.txt   # regenerate after any lock change
```

CI runs the suite on Python 3.11, 3.12, 3.13 and 3.14, and fails if `uv.lock` or `requirements.txt` is out of date.

## Full Documentation

See [docs/guide.md](docs/guide.md) for the complete endpoint list, query parameter support ($filter, $expand, $top), write operations, error simulation, Docker Compose setup, and runtime overrides.
