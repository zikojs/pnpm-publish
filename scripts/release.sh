
#!/usr/bin/env bash
set -euo pipefail

REMOTE="origin"
PREFIX="workflow-v"

read -rp "Enter release version (e.g. 1.0.0 or 1.0.0-beta.1): " VERSION

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
  echo "Invalid version: $VERSION"
  exit 1
fi

TAG="${PREFIX}${VERSION}"

# Ensure the tag does not already exist
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Tag already exists locally: $TAG"
  exit 1
fi

if git ls-remote --exit-code --tags "$REMOTE" "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "Tag already exists remotely: $TAG"
  exit 1
fi

# Ensure there are changes to commit
if [[ -n "$(git status --porcelain)" ]]; then
  git add .
  git commit -m "chore: release $VERSION"
else
  echo "No changes to commit."
fi

# Create and push release tag
git tag "$TAG"
git push "$REMOTE" HEAD
git push "$REMOTE" "$TAG"

echo "Released tag: $TAG"
