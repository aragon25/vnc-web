# vnc-web

Lightweight web-accessible VNC gateway packaged as a Debian `.deb` for
Debian/Raspbian targets. This project provides a simple way to expose a VNC
session through a browser for remote troubleshooting of headless devices. The
repository contains packaging helpers so the upstream components are bundled for
easy installation.

## 📌 Features

- Serve a web-accessible VNC client (browser) to a local VNC server
- Simple configuration and systemd integration provided by the package
- Packaged as a `.deb` for easy install and removal

---

## 📂 Installation

### Install via `.deb`

Download the release package and install on the device:

```bash
wget https://github.com/aragon25/vnc-web/releases/download/v1.3-1/vnc-web_1.3-1_all.deb
sudo apt install ./vnc-web_1.3-1_all.deb
```

---

## 🧩 Runtime dependencies

The installer script and runtime expect the following packages to be available
on the target system (these are installed by the packaging or should be
installed via your package manager):

- `x11vnc` — VNC server exposing the local X session
- `websockify` — WebSocket to TCP proxy used to bridge browser VNC clients to
  the VNC server
- `nginx` — optional HTTP server / reverse proxy for the web frontend
- `openssl` — for generating SSL certificates and enabling TLS for WebSocket

On Debian/Raspbian you can install them with:

```bash
sudo apt update
sudo apt install x11vnc websockify nginx openssl
```

Note: `websockify` may be provided as a Python package in some distributions
(`websockify` or `python3-websockify`). The packaging scripts assume the
runtime `websockify` command is available on `PATH` (see `src/vnc-web.sh`).
If you prefer not to bundle `websockify`, mark it as a runtime dependency in
the package metadata instead.

## ⚙️ Usage

After installation, a systemd unit (if provided by the package) will expose the
web frontend on the configured port. Typical usage examples:

```bash
# check service status
sudo systemctl status vnc-web.service

# enable and start the service
sudo vnc-web -e

# disable and stop the service
sudo vnc-web -d

# change password
sudo vnc-web -p={password} 

# access the web UI on the configured port (e.g. http://<host>:8090/)
```

Configuration and default ports are provided by the package; consult the
installed `/etc/vnc-web/` configuration files when present.

---

## ⚠️ Safety

- Exposing remote desktop over the network can be insecure. Ensure firewall
  rules, authentication, and TLS termination are configured appropriately.
- Prefer VPN or SSH tunnels for remote access in production environments.

---

## 📦 Provenance & Licenses

- If this package bundles or includes upstream components (third-party
  libraries, web-client code, or binaries), record their origin and license in
  `UPSTREAM_SOURCES.md` at the repository root. Each entry should include:
  - file or folder included (relative path)
  - upstream project URL and exact tag/commit (e.g. `https://... @ v1.2.3`)
  - declared license (SPDX identifier if available)

- Include copies of each upstream `LICENSE` file in a `licenses/` directory or
  place the upstream license text next to the bundled files. Do not remove or
  alter license headers present in upstream source files.

- Verify license compatibility before packaging. If an upstream component has
  a restrictive license that prevents redistribution, do not include it in the
  packaged artifact; instead document the dependency and provide installation
  instructions that fetch it at runtime.

- When building the `.deb`, include proper copyright and license metadata in
  the packaging control files (e.g., `debian/copyright` or the equivalent
  `deploy/config` fields) and list SPDX identifiers where possible.

- If an upstream project requires attribution or a NOTICE file, include that
  attribution in the package and in `UPSTREAM_SOURCES.md`.
