# 9in CLI

The command-line tool for [9in](https://9in.io), hosted login and single sign-on.

- **`9in connect`** sets up your project in a 9in tenant with one confirmation (application,
  webhook, user database adapter) and writes the settings to your `.env`.
- **`9in listen`** gives a local server a stable public https URL, so 9in can reach your
  webhook and adapter while you develop, with a request inspector and replay.
- **`9in dev`** does both: a tunnel to your app, and the project connected through it.

## Install

macOS and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/9in-io/cli/master/install.sh | sh
```

Homebrew (macOS):

```sh
brew tap 9in-io/cli https://github.com/9in-io/cli
brew install --cask 9in-io/cli/9in
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/9in-io/cli/master/install.ps1 | iex
```

Or download an archive for your platform from the [releases](https://github.com/9in-io/cli/releases)
(darwin, linux and windows on amd64 and arm64) and check it against `checksums.txt`. The install
scripts verify the checksum before installing. `NINE_VERSION=2.0.0` installs a given version;
`NINE_INSTALL_DIR` chooses the directory.

`9in update` replaces the binary with the latest release (after checking its checksum); the CLI
tells you about new releases at most once a day.

## Quick start

```sh
9in login            # sign in to your 9in account in the browser
cd my-app
9in connect          # review the setup in the console, confirm, and .env is written
9in dev              # or: a tunnel to your app, with webhooks and the adapter through it
```

## Commands

| Command | What it does |
| --- | --- |
| `9in login` | Signs in to your 9in account in the browser and keeps the session in your OS keychain. `--no-browser` prints the URL. |
| `9in logout` | Revokes the session at 9in and deletes it locally. |
| `9in whoami` | Shows the signed-in account (`--json`). |
| `9in tenants list` | Lists your tenants with their issuer URLs (`--json`). |
| `9in apps list [-t <tenant>]` | Lists a tenant's applications and redirect URLs (`--json`). |
| `9in connect` | Sets up the project in a tenant and writes its settings. See below. |
| `9in dev` | Opens a tunnel to your app and connects the project through it. |
| `9in listen <port \| host:port \| URL>` | Exposes a local server at `https://<id>-tunnel.9in.io`. |
| `9in serve [dir]` | Serves files on `http://127.0.0.1:8080`, or as a mock adapter; `--public` adds a tunnel. |
| `9in update` | Installs the latest release (`--check` only checks). |
| `9in version` | Prints the version. |
| `9in completion <shell>` | Shell completion for bash, zsh, fish and PowerShell. |

Every command has `--help` with all its flags.

### `9in connect`

```sh
9in connect                                          # local development (sandbox)
9in connect --url https://shop.example --webhook     # also the production URL and a webhook
9in connect --environment production --yes
9in connect --dry-run                                # show the plan and the request only
```

1. The CLI recognizes the project and what the 9in SDKs expect:

   | Project | Settings file | Redirect URL | Webhook | Adapter |
   | --- | --- | --- | --- | --- |
   | Laravel (`9in/laravel-sdk`, `9in/laravel-server`) | `.env` | `APP_URL` + `/nine/callback` | `/nine/webhook` | `/nine` |
   | Next.js | `.env.local` | `/callback` (`/api/auth/callback/nine` with Auth.js) | `/api/webhooks/9in` | `/api/nine` |
   | Express and other Node apps (`@9in-io/node`, `@9in-io/express-server`) | `.env` | `/callback` | `/webhooks/9in` | `/nine` |
   | Vite single-page apps | `.env.local` (`VITE_NINE_*`) | `/callback` | | |
   | PHP (`9in/php-sdk`) | `.env` | `/callback.php` | `/webhook.php` | `/nine` |

   Flags override everything: `--local-url`, `--url`, `--callback`, `--webhook-path`,
   `--adapter-path`, `--env-file`, `--name`, `--app-type`.
2. It shows the proposal (numbered steps) and the variables it will write, and asks before
   opening the console.
3. In the console you sign in, choose the tenant and environment, see each change marked
   **Create**, **Update** or **Unchanged**, and confirm (or cancel: nothing changes).
4. The CLI receives the credentials once and writes `NINE_ISSUER`, `NINE_CLIENT_ID`,
   `NINE_CLIENT_SECRET`, `NINE_WEBHOOK_SECRET`, `NINE_ADAPTER_SECRET` and `NINE_CONNECTION_ID`.
   Other lines of the file stay as they are. Secrets are never printed.

Adapter options: `--adapter on|off|auto|remove` (`remove` retires the adapter this project
connected, so the tenant goes back to users stored in 9in) and `--import-users` (copy each user,
with their password, into 9in at their first sign-in).

Running it again updates the same setup instead of creating new resources (`NINE_CONNECTION_ID`).
Secrets are only issued for new resources; `--rotate` asks for new ones. Webhooks and the adapter
need a URL 9in's servers can reach: `--url` for a deployed app, or the tunnel with `9in dev`.
Without `--environment`, local setups go to the **sandbox** environment and production-only
setups to **production**.

### `9in dev`

```sh
9in dev                         # detects the port (8000 for Laravel, 3000 for Node, …)
9in dev --port 8080 --webhook --adapter on
```

Opens a tunnel named after the project, then runs `9in connect` with the tunnel's URL for the
webhook (when a 9in package that receives webhooks is installed, or `--webhook`) and the adapter
(when an adapter package is installed, or `--adapter on`). The tunnel URL is the same every time
for your account and project, so after the first run there is nothing to confirm until the
setup changes (`--reconnect` reviews it anyway).

### `9in listen`

```sh
9in listen 8000
9in listen localhost:5173 --host-header rewrite     # dev servers that check the Host header
9in listen https://localhost:8443 --tunnel api      # a second tunnel with its own URL
```

```
● Tunnel online (default)
  Public URL  https://k3x9p2qa7mfz4w8r-tunnel.9in.io
  Forwarding  → http://localhost:8000
  Inspector   http://127.0.0.1:4040

02:14:07  POST    /nine/webhook   200 12ms ✓ signed (webhook)
```

- **Stable URL.** The URL depends only on your account and the tunnel name (`--tunnel`,
  default `default`), so URLs saved in 9in keep working between runs. You can use up to 10
  names a day.
- **Inspector.** `http://127.0.0.1:4040` lists every request with headers and bodies (JSON pretty
  printed, gzip decoded), lets you **replay** a request against your local server and copy it as
  curl. When the project's `.env` has `NINE_WEBHOOK_SECRET` or `NINE_ADAPTER_SECRET`, each
  request's `9in-signature` is checked. `--inspect <addr>` moves it, `--no-inspect` turns it off.
- **Headers.** Your server sees the public `Host` (so it builds correct absolute URLs) and
  `X-Forwarded-For`, `X-Forwarded-Proto: https` and `X-Forwarded-Host`. `--host-header rewrite`
  sends the local host instead.
- **Limits.** Request bodies up to 10 MB, responses up to 50 MB, 240 requests a minute and
  10,000 a day per tunnel, 60 seconds to start answering. A tunnel closes after 8 hours without
  requests. HTTP only: WebSocket upgrades through a tunnel are not supported.

### `9in serve`

```sh
9in serve ./public
9in serve ./mock-adapter --public --secret "$NINE_ADAPTER_SECRET"
```

Serves a directory on `http://127.0.0.1:8080` (`--addr`), with CORS headers (`--cors=false`).
It can stand in for an adapter while you build one: any method gets the file at the path or the
path plus `.json` (`POST /nine/user` → `nine/user.json`), and JSON answers are signed with the
adapter secret (`--secret`, `NINE_ADAPTER_SECRET`, or the project's `.env`) over
`<path>#<9in-request-id>`, as 9in verifies them.

## How it works

### Connect

```
9in CLI                          your browser                      9in console
  │ 1. POST /api/connect/requests (proposal, PKCE challenge)          │
  │──────────────────────────────────────────────────────────────────▶│
  │ 2. open the console ─────────▶│ 3. sign in, choose the tenant,     │
  │                               │    review the plan, confirm ──────▶│ 4. apply + audit log
  │◀── 5. one-time code (http://127.0.0.1:<port>/callback) ───────────│
  │ 6. POST /api/connect/token (code + PKCE verifier) ───────────────▶│
  │◀──────────── issuer, client id and secrets (once) ────────────────│
```

The CLI only proposes; you decide in the console, and every change is in the tenant's audit log.
The one-time code is useless without the PKCE verifier that only this CLI run holds, and it
returns to a loopback address on your machine. Connections are listed under the tenant's
**Integrations** in the console, where you can disconnect them.

### Tunnels

```
browser / 9in ──https──▶ <id>-tunnel.9in.io ──▶ Cloudflare Worker ──▶ Durable Object (one per tunnel)
                                                                            │ WebSocket
                                          your app ◀── http ── 9in listen ◀─┘
```

The CLI holds a WebSocket to a Cloudflare Durable Object that belongs to your tunnel. Each
request to the public URL is relayed over it, with bodies streamed in 64 KiB frames in both
directions, and your app's answer goes back the same way. The connection is authenticated with
your 9in session; an idle connection costs nothing and is kept alive with small pings.

## Configuration

| Variable | Use |
| --- | --- |
| `NINE_CLI_TOKEN` | An access token to use instead of the stored session (CI). |
| `NINE_CLI_KEYRING=off` | Store the session in a file (0600) instead of the OS keychain. |
| `NINE_CLI_CONFIG_DIR` | Where the CLI keeps its files (default: your config directory + `/9in`). |
| `NINE_CLI_NO_UPDATE_CHECK=1` | Never check for new releases (also off when `CI` is set). |
| `NINE_CLI_NO_BROWSER=1` | Never open a browser; print URLs instead. |
| `NINE_CLI_ISSUER`, `NINE_CLI_CONSOLE`, `NINE_CLI_TUNNEL` | Other 9in endpoints (staging, local development). |
| `NINE_CLI_AUDIENCE` | Audience of the account token (default: the console URL, `https://app.9in.io`). |
| `NO_COLOR` | Plain output. |

The CLI's own variables start with `NINE_CLI_`, so a shell that loaded your project's `.env`
(`NINE_ISSUER`, `NINE_CLIENT_ID`, …) never changes where the CLI signs in.

## Security notes

- **Your session** comes from the authorization code flow with PKCE against
  `https://login.9in.io`, with the redirect on `127.0.0.1`. The token is issued for the console
  API only (audience `https://app.9in.io`, scope `console`). It is kept in the macOS Keychain,
  Windows Credential Manager or the Secret Service on Linux; without one, in a file only you can
  read. Refresh tokens rotate; `9in logout` revokes the session.
- **Connect** never gives the CLI a console session: it receives only the credentials of what you
  approved, for one tenant, once. Secrets go straight into your settings file (created with mode
  0600) and are never printed; the CLI warns when that file is not in `.gitignore`.
- **Tunnels** make a local server reachable from the internet while they run. Only expose
  development servers, stop the tunnel when you are done (it also closes after 8 hours without
  requests), and keep your adapter and webhook signature checks on: requests from 9in carry a
  `9in-signature` that the SDKs verify. Tunnel URLs are not guessable, but they are not secret
  either.
- **The inspector** listens on 127.0.0.1 only, refuses other host names and cross-site writes,
  and keeps the last 200 requests in memory. It shows bodies and headers, including tokens.
- **Updates** are checked against `checksums.txt` of the release before the binary is replaced.

## Coming from the SSOfy dev tool

The `ssofy` binary (1.x) talked to SSOfy, which no longer exists. 9in CLI 2.x replaces it:
`ssofy listen <port> -k <key>` becomes `9in login` once, then `9in listen <port>`; API keys are
gone. Remove the old binary and install this one.

## Support

Questions and problems: [9in.io](https://9in.io).

## License

The binaries are distributed under the [9in CLI Binary Distribution License](LICENSE).
9in is by [Cubelet Ltd](https://cubelet.co.uk).
