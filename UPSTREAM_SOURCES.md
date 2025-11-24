# UPSTREAM_SOURCES.md

Purpose
- Record provenance for third-party code, web components, binaries or other
  artifacts bundled into this repository or the `.deb` produced by the package.

Format
- Maintain one entry per bundled upstream component. Use either a simple
  Markdown table or bullet list. Each entry should include at minimum:
  - `path` (relative path inside this repo where the files are included)
  - `upstream` (URL to upstream project)
  - `version` (tag, release name, or commit hash)
  - `license` (SPDX identifier where possible)
  - `notes` (short note about why included / build adjustments)

Example (table)

| path | upstream | version | license | notes |
|------|----------|---------|---------|-------|
| `src/noVNC-1.6.0/noVNC-1.6.0/` | `https://github.com/novnc/noVNC` | `v1.6.0` | `MPL-2.0` (see `licenses/noVNC-LICENSE.txt`) | Bundled browser VNC client (web UI)
| `src/noVNC-1.6.0/noVNC-1.6.0/vendor/pako/` | `https://github.com/nodeca/pako` | (bundled vendor copy) | `MIT` (see `licenses/pako-LICENSE.txt`) | zlib deflate/inflate library used by noVNC

Example (bullet)

- path: `src/bin/some-binary`
  - upstream: `https://example.org/upstream-project @ abcdef123456`
  - license: `MIT` (SPDX)
  - notes: linked to build script `deploy/builder/foo`

Checklist (what to do for each bundled upstream component)

1. Add an entry to this file with the exact upstream URL and tag/commit.
2. Save a copy of the upstream `LICENSE` into `licenses/` (create if missing),
   using the upstream project's license file name (e.g. `LICENSE`, `COPYING`).
3. Preserve upstream license headers in source files; do not remove or alter
   copyright attributions.
4. If the upstream license imposes redistribution restrictions, do not bundle
   the component into the `.deb`; instead document the dependency and provide
   install-time instructions.
5. Update package metadata (`deploy/config/*` or `debian/*`) with license info
   and SPDX identifiers where appropriate.

Quick commands (examples)

```bash
# create licenses/ and fetch upstream license (edit URL/filename as needed)
mkdir -p licenses
curl -L 'https://raw.githubusercontent.com/novnc/noVNC/v1.4.0/LICENSE' -o licenses/noVNC-LICENSE.txt
```

Notes
- This file is intended as a minimal, copyable provenance record to satisfy
  basic license compliance and auditing. For formal packaging (Debian
  packages) ensure you also supply the correct `debian/copyright` or other
  packaging-specific metadata.

If you like, I can now scan `src/` and `vendor/` (if present) for likely
third-party files and propose entries to add to this file.
