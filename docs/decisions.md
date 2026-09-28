# m365-sim Design Decisions

## Decision Log

Each entry records a design question, the options considered, the resolution, and the rationale.

---

### DEC-001: Fixture Loading Strategy

**Date**: 2026-03-19
**Status**: DECIDED
**Question**: Should fixture JSON files be loaded eagerly at server startup or lazily on first request?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Eager loading at startup | Simple dict lookup, startup errors surface immediately, no race conditions | Slightly slower startup (negligible for <500KB) |
| B. Lazy loading on first request | Marginally faster startup | Added complexity, first-request latency, potential race conditions |

**Resolution**: A — Eager loading at startup
**Rationale**: ~30 JSON files totaling under 500KB is negligible memory. Eager loading eliminates race conditions, simplifies code, and surfaces startup errors immediately rather than on first request.

---

### DEC-002: $filter Implementation Depth

**Date**: 2026-03-19
**Status**: DECIDED
**Question**: Should the mock server ignore OData $filter query parameters or implement a minimal filter engine?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Ignore all filters, return full fixture | Simplest implementation, evaluators handle full results | Won't catch filter-dependent bugs |
| B. Minimal filter engine for `eq` comparisons | More realistic, catches evaluator assumptions about pre-filtered data | More code to maintain, risk of filter bugs in the mock itself |

**Resolution**: A — Ignore all filters for MVP
**Rationale**: Compliance evaluators already handle full result sets. Fixtures are curated to contain only relevant entities (no room mailboxes, guest noise), so filters aren't needed yet. When noisy/realistic fixtures are added later, a minimal filter engine becomes valuable — flagged as a future enhancement.

---

### DEC-003: Stateful Write Operations

**Date**: 2026-03-19
**Status**: DECIDED
**Question**: Should POST/PATCH operations mutate in-memory fixture state, or return fake responses without changing state?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Stateless — fake responses only | Simple, hardened scenario is a separate fixture set, no reset mechanism needed | Can't test deploy-then-verify flows in a single test run |
| B. Stateful — writes mutate in-memory state | Enables deploy-then-verify testing, more realistic | Merge logic complexity, needs reset mechanism, harder to reason about test state |

**Resolution**: A — Stateless for MVP
**Rationale**: The hardened fixture set represents the post-deploy state. As long as the remediation tool's output matches the hardened fixtures, the assess-deploy-assess flow works via scenario switching (greenfield → hardened). Stateful writes deferred to v2 for when deploy output diverges from static fixtures or single-run deploy-then-verify is needed.

---

### DEC-004: Integration Test Runner

**Date**: 2026-03-19
**Status**: DECIDED
**Question**: Should smoke tests start the mock server as a subprocess (real HTTP) or use in-process ASGI transport?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Subprocess (real HTTP via httpx) | Tests real server startup, actual HTTP layer consumers use, catches port/process issues | Slower, potential port conflicts, process management in fixtures |
| B. In-process ASGI transport | Fast, no port conflicts, simpler fixture setup | Skips real HTTP layer, doesn't test server startup path |
| C. Both — subprocess for integration, ASGI for unit | Best coverage, fast unit tests + realistic integration tests | Two test patterns to maintain |

**Resolution**: A — Subprocess with real HTTP
**Rationale**: Compliance tools will hit this server over real HTTP. Subprocess tests match the real-world usage pattern, catching server startup issues, CLI arg parsing, and HTTP layer bugs that in-process tests would miss. The few extra seconds of test time are worth the realism.

---

### DEC-005: TenantBuilder Timing

**Date**: 2026-03-19
**Status**: DECIDED
**Question**: Should the TenantBuilder fluent API be part of the MVP or deferred until after greenfield/hardened fixtures and smoke tests are working?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Include in MVP (Phase 04-ish) | Available immediately for generating test variants | No value until basic fixtures work, delays core deliverable |
| B. Defer to Phase 08 | Focus on core value first, builder becomes useful when we need custom scenarios | Greenfield/hardened are hand-authored, could be error-prone |

**Resolution**: B — Defer to Phase 08
**Rationale**: The kickoff spec provides exact JSON for greenfield and hardened scenarios. Hand-authoring these fixtures is straightforward. The builder becomes valuable after the foundation works, when custom scenarios are needed for edge-case testing (e.g., partial deployments, large tenant simulation).

---

### DEC-006: Python Version and Project Manager

**Date**: 2026-09-28
**Status**: DECIDED
**Question**: Which Python should the project target now that 3.14 is the current stable release, and should dependency management move from pip + `requirements.txt` to uv?

**Options**:
| Option | Pros | Cons |
|--------|------|------|
| A. Stay on pip, bump CI matrix only | No tooling change for contributors | No lockfile: unpinned resolves drift (on 3.15 one silently fell back to pydantic 1 and broke at import); runtime and test deps stay mixed, so the Docker image ships pytest |
| B. uv with `pyproject.toml` + `uv.lock`, keep a generated `requirements.txt` | Reproducible installs; uv provisions interpreters; PEP 735 dev group splits test tooling out; pip/Docker users unaffected | Contributors need uv >= 0.12.2; generated file must be kept in sync (enforced in CI) |
| C. uv, drop `requirements.txt`, uv-based Docker image | Single source of truth | Breaks pip-only consumers; larger Dockerfile change for no runtime benefit today |

**Resolution**: B — uv with a lockfile; default interpreter 3.14; `requires-python >=3.11`
**Rationale**: The full suite passes unchanged on 3.11, 3.12, 3.13 and 3.14.7 (no deprecation warnings), so the floor stays at 3.11 until its October 2027 EOL while development, Docker and the default `.python-version` move to 3.14. A lockfile removes resolver drift, and `uv export --no-dev` keeps `requirements.txt` for Docker and pip users with hashes and without test tooling. CI checks both the lock and the export. 3.15 is deferred until pydantic-core, httptools and uvloop publish cp315 wheels; add it then as a non-blocking matrix leg.

