# PNPM Workspace Publisher

Build and publish pnpm workspace packages to npm with automatic dist-tag detection, selective builds, optional template synchronization, and support for npm trusted publishing.

## Features

- **pnpm workspace support:** Build and publish multiple packages from a pnpm workspace.
- **Automatic pnpm detection:** Detects the pnpm version from `packageManager` in `package.json`, with a configurable fallback.
- **Automatic dist-tag detection:** Determines the npm dist-tag from Git tags (`latest`, `beta`, `alpha`, `rc`, `next`, etc.).
- **Selective builds:** Build packages using pnpm filters.
- **Template synchronization:** Replace `workspace:` and `catalog:` dependencies in template manifests with npm-compatible versions.
- **Two synchronization modes:** Use local workspace versions immediately or publish dependencies first and wait for npm availability.
- **Dry-run support:** Preview packages before publishing.
- **npm authentication:** Supports npm tokens and trusted publishing.
- **Configurable publishing:** Control npm access, build failure behavior, and publishing options.

## Usage

Create a workflow in `.github/workflows/publish.yml`:

```yaml
name: Publish packages

on:
  push:
    tags:
      - "v*"

  workflow_dispatch:
    inputs:
      tag:
        description: "npm dist-tag"
        required: true
        default: latest
        type: choice
        options: [latest, next, beta, alpha, rc]

permissions:
  contents: read

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - uses: zikojs/pnpm-publish@v1.3
        with:
          tag-prefix: v
          dist-tag: ${{ inputs.tag }}
          npm-token: ${{ secrets.NPM_TOKEN }}
```

For npm trusted publishing, configure your npm package's trusted publisher and omit `npm-token`.

## Inputs

| Input | Description | Default |
|---|---|---|
| `tag-prefix` | Git tag prefix to strip when deriving the version | `v` |
| `dist-tag` | Explicit npm dist-tag; overrides automatic detection | `""` |
| `default-dist-tag` | Fallback dist-tag when no Git tag is available | `latest` |
| `packages-dir` | Directory containing packages to publish | `packages` |
| `build-filter` | pnpm filter expression used for builds | `./packages/**` |
| `pnpm-version` | Fallback pnpm version if `packageManager` is absent | `12` |
| `npm-token` | npm authentication token; omit for trusted publishing | `""` |
| `access` | npm access level (`public` or `restricted`) | `""` |
| `dry-run-only` | Preview packages without publishing | `false` |
| `fail-on-build-error` | Fail if the build command fails | `true` |
| `sync-templates` | Enable temporary template dependency synchronization | `false` |
| `template-patterns` | Newline-separated template directory patterns relative to repository root | `packages/*/templates/*` |
| `template-sync-mode` | Template synchronization mode: `unchecked` or `wait` | `unchecked` |
| `dependency-filter` | pnpm filter selecting dependencies to publish before template synchronization in `wait` mode | `""` |
| `publish-timeout` | Maximum seconds to wait for npm package availability | `300` |
| `publish-interval` | Seconds between npm availability checks | `10` |

## Dist-tag detection

When `dist-tag` is not explicitly provided, the action derives it from the Git tag.

| Git tag | npm dist-tag |
|---|---|
| `v1.0.0` | `latest` |
| `v1.1.0-beta.1` | `beta` |
| `v1.1.0-alpha.2` | `alpha` |
| `v1.1.0-rc.1` | `rc` |
| `v1.1.0-next.3` | `next` |

The prerelease identifier is extracted from the portion after the first hyphen. If it is not