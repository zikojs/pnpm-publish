

# PNPM Workspace Publisher

Build and publish pnpm workspace packages to npm with automatic dist-tag detection, optional template synchronization, and support for npm trusted publishing.

## Features

- **pnpm workspace support** : Build and publish multiple packages from a pnpm workspace.
- **Automatic pnpm detection** : Detects the pnpm version from `packageManager` in `package.json`, with a configurable fallback.
- **Automatic dist-tag detection** : Determines the npm dist-tag from Git tags (`latest`, `beta`, `alpha`, `rc`, etc.).
- **Selective builds** : Build packages using pnpm filters.
- **Template synchronization** : Temporarily replace `workspace:*` and `catalog:` dependencies in template manifests with published npm versions.
- **Lockfile synchronization** : Regenerate the lockfile when template synchronization is enabled.
- **Dry-run support** : Preview packages before publishing.
- **npm authentication** : Supports npm tokens and trusted publishing.
- **Configurable publishing** : Control npm access and build failure behavior.

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
        options: [latest, next, beta]

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

      - uses: zikojs/pnpm-publish@v1
        with:
          tag-prefix: v
          dist-tag: ${{ inputs.tag }}
          npm-token: ${{ secrets.NPM_TOKEN }}
```

For npm trusted publishing, configure your npm package's trusted publisher and omit `npm-token`.

## Inputs

| Input | Description | Default |
|-|-|-|
| `tag-prefix` | Git tag prefix to strip when deriving the version | `v` |
| `dist-tag` | Explicit npm dist-tag; overrides automatic detection | `""` |
| `default-dist-tag` | Fallback dist-tag when no tag is available | `latest` |
| `packages-dir` | Directory containing packages to publish | `packages` |
| `build-filter` | pnpm filter expression used for builds | `./packages/**` |
| `pnpm-version` | Fallback pnpm version if `packageManager` is absent | `12` |
| `npm-token` | npm authentication token | `""` |
| `access` | npm access level (`public` or `restricted`) | `""` |
| `dry-run-only` | Preview packages without publishing | `false` |
| `fail-on-build-error` | Fail if the build command fails | `true` |
| `sync-templates` | Enable temporary template dependency synchronization | `false` |
| `template-patterns` | Newline-separated template directory patterns | `scafy/templates/*` |

## Dist-tag detection

When `dist-tag` is not explicitly provided, the action derives it from the Git tag.

| Git tag | npm dist-tag |
|-|-|
| `v1.0.0` | `latest` |
| `v1.1.0-beta.1` | `beta` |
| `v1.1.0-alpha.2` | `alpha` |
| `v1.1.0-rc.1` | `rc` |
| `v1.1.0-next.3` | `next` |

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
- uses: zikojs/pnpm-publish@v1
  with:
    npm-token: ${{ secrets.NPM_TOKEN }}
    sync-templates: true
    template-patterns: |
      templates/*
      packages/*/templates/*
      scafy/templates/*
```

The action:

1. Prepares matching templates by replacing workspace and catalog dependencies with published npm versions.
2. Regenerates the pnpm lockfile.
3. Installs dependencies and builds packages.
4. Publishes packages.
5. Restores the original template manifests.

The restoration step runs even when a later step fails, provided preparation completed successfully.

**Note:** Template synchronization requires the `createTemplateSync` implementation and its dependencies to be available to the action.

## Selective builds

Use `build-filter` to control which workspace packages are built.

For example:

```yaml
build-filter: |
  @scope/core
  @scope/utils
  @scope/plugin-*
```

To exclude template projects:

```yaml
build-filter: "./packages/**"
```

The build command uses recursive pnpm execution with `--if-present`.

## Dry run

To validate the workflow without publishing:

```yaml
- uses: zikojs/pnpm-publish@v1
  with:
    dry-run-only: true
```

The action still installs dependencies, builds packages, and previews the publishing operation.

## npm authentication

### Using an npm token

Add an `NPM_TOKEN` repository secret and configure:

```yaml
- uses: zikojs/pnpm-publish@v1
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

The action uses `packageManager` from the root `package.json` when available. Otherwise, it uses the configured `pnpm-version`.

## License

MIT

