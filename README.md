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

The prerelease identifier is extracted from the portion after the first hyphen. If it is not a valid npm dist-tag identifier, `beta` is used.

If the workflow is not triggered by a Git tag, `default-dist-tag` is used.

An explicitly provided `dist-tag` always takes precedence.

## Template synchronization

Some pnpm workspaces contain starter templates that use workspace or catalog dependencies:

```json
{
  "dependencies": {
    "ziko": "workspace:*",
    "vite": "catalog:"
  }
}
```

These protocols are useful during development but are not suitable for templates intended to be installed independently.

Enable synchronization:

```yaml
- uses: zikojs/pnpm-publish@v1.3
  with:
    npm-token: ${{ secrets.NPM_TOKEN }}
    sync-templates: true
    template-patterns: |
      templates/*
      packages/*/templates/*
      scafy/templates/*
```

Patterns are relative to the repository root.

The action temporarily replaces workspace and catalog dependency specifications with npm-compatible versions derived from the workspace package versions and catalog definitions.

### Synchronization modes

The `template-sync-mode` input supports two modes.

#### 1. Unchecked mode (default)

```yaml
- uses: zikojs/pnpm-publish@v1.3
  with:
    sync-templates: true
    template-sync-mode: unchecked
```

In this mode:

1. Installs dependencies using the original workspace manifests and lockfile.
2. Builds workspace packages.
3. Prepares templates using local workspace versions.
4. Previews and publishes packages.
5. Restores the original template manifests.

No npm availability checks or early dependency publishing are performed.

**Important:** A template can reference a package version that has not yet been published. Installing that template before the referenced version becomes available on npm will fail.

#### 2. Wait mode

Use this mode when templates must reference versions that are already published on npm.

```yaml
- uses: zikojs/pnpm-publish@v1.3
  with:
    npm-token: ${{ secrets.NPM_TOKEN }}
    sync-templates: true
    template-sync-mode: wait
    dependency-filter: |
      ziko
      @zikojs/html
    publish-timeout: 300
    publish-interval: 10
```

The action follows this sequence:

1. Installs dependencies using the original workspace manifests.
2. Builds workspace packages.
3. Publishes packages matching `dependency-filter`.
4. Checks npm for each selected package's exact version.
5. Waits until all selected versions are available or the timeout is reached.
6. Prepares templates using npm-compatible dependency versions.
7. Previews and publishes the remaining packages.
8. Restores the original template manifests.

The final recursive publishing operation excludes packages selected by `dependency-filter`, preventing the action from attempting to publish them a second time.

**Important considerations:**

- `dependency-filter` must select all packages that templates depend on and that need to be published first.
- Packages selected by this filter are published in the early publishing stage and excluded from the final publishing stage.
- npm availability checks confirm that the exact package versions are visible on the registry. They do not guarantee that package installation or access will succeed.
- If a selected package fails to publish or does not become available before the timeout, the action fails.
- Early-published dependencies remain published if a later step fails. npm publications cannot be automatically rolled back.

### Dry-run behavior

When `dry-run-only: true` is used, early dependency publishing and npm availability checks are skipped, even in `wait` mode. Templates are prepared using local workspace versions, and the publishing operation is previewed without publishing.

### Template restoration

The action restores original template manifests after the publishing process. Restoration also runs if a later step fails, provided template preparation completed successfully.

The root lockfile is not regenerated during template synchronization. Avoid running another workspace installation after preparation, since rewritten dependency versions might not yet be available on npm in unchecked mode.

## Selective builds

Use `build-filter` to control which workspace packages are built.

For example:

```yaml
build-filter: |
  @scope/core
  @scope/utils
  @scope/plugin-*
```

The build command uses recursive pnpm execution with `--if-present`.

To avoid building template projects, configure your filter to select only actual buildable packages.

## Dry run

To validate the workflow without publishing:

```yaml
- uses: zikojs/pnpm-publish@v1.3
  with:
    dry-run-only: true
```

The action still installs dependencies, builds packages, and previews the publishing operation.

In template synchronization `wait` mode, early publishing and registry checks are skipped during dry runs.

## npm authentication

### Using an npm token

Add an `NPM_TOKEN` repository secret and configure:

```yaml
- uses: zikojs/pnpm-publish@v1.3
  with:
    npm-token: ${{ secrets.NPM_TOKEN }}
```

### Using npm trusted publishing

Configure GitHub Actions as a trusted publisher in npm, then grant the workflow:

```yaml
permissions:
  contents: read
  id-token: write
```

Omit `npm-token` when using trusted publishing.

## Requirements

- A pnpm workspace.
- A root `package.json`.
- A valid `pnpm-lock.yaml`.
- Packages with valid npm publishing metadata.
- The action's template synchronization script and implementation when `sync-templates` is enabled.

The action uses `packageManager` from the root `package.json` when available. Otherwise, it uses the configured `pnpm-version`.

## License

MIT