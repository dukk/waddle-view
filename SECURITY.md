# Security policy

## Supported versions

Security fixes are provided for the **latest** `v*` [GitHub Release](https://github.com/dukk/waddle-view/releases) and for commits on the default branch (`main`) until a newer release is published. Older tags are not maintained unless noted in a release advisory.

## Reporting a vulnerability

**Do not** open a public GitHub issue for undisclosed security problems.

Report privately to **dukk@dukk.org** (see also [LICENSE](LICENSE) for commercial licensing contact). Include:

- Affected component (`waddle_display`, `waddle_controller` BFF, `waddlectl`, deploy scripts)
- Version or commit SHA
- Steps to reproduce and impact
- Any suggested fix (optional)

We aim to acknowledge reports within a few business days. Coordinated disclosure is preferred; please allow reasonable time for a fix before public discussion.

## What not to paste in public issues or PRs

- Display **instance id** files (`waddle_instance.id`, `/etc/waddle-view/instance.id`) — these are HMAC secrets for adoption, not bearer tokens, but they must stay private
- Adopted REST **API keys** (`wd_…` prefix)
- Integration secrets, OAuth tokens, backup archives, or database dumps
- Controller **session** cookies or `WADDLE_CONTROLLER_SESSION_SECRET` values
- Production hostnames, internal URLs, or `.env` contents

The [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) repeats this guidance.

## Deployment threat model (summary)

Waddle View is designed for **trusted LAN / home** operator use:

- The display REST server defaults to **`0.0.0.0:8787`** with **self-signed TLS**. Anyone who can reach the port can attempt adoption while challenges are allowed; restrict bind address (`WADDLE_DISPLAY_HTTP_BIND_IP=127.0.0.1`) and firewall when exposing beyond a private network.
- **Adoption** shows an on-screen challenge; only clients that complete `POST /v1/adoption/confirm` receive an API key. Admin keys can grant additional clients without a challenge — protect admin credentials.
- Integration API keys are stored **encrypted at rest** in SQLite (`integration_secrets`); root access to the device or database file can still decrypt them.
- The controller BFF may proxy to displays with **`rejectUnauthorized: false`** for self-signed display certificates — expected on LAN; do not expose the BFF to untrusted networks without TLS termination and auth (`WADDLE_CONTROLLER_AUTH_ENABLED=1` with a strong `WADDLE_CONTROLLER_SESSION_SECRET`).

See [`docs/pi/api.md`](docs/pi/api.md) and [`apps/waddle_display/README.md`](apps/waddle_display/README.md) for authentication and CORS details.

## Dependency audits (maintainers)

From the repository root:

```bash
python scripts/security_audit.py
```

Review `.cursor/hooks/state/security-audit.json` (gitignored) or fix critical/high findings before tagging a release. CI does not yet run this script automatically; see [CONTRIBUTING.md](CONTRIBUTING.md).
