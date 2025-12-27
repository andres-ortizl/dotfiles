#!/usr/bin/env bash
# Auto-build and attach debug toolbox to a container

set -e

TARGET_CONTAINER="$1"
IMAGE="debug-toolbox:latest"
DOCKERFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$TARGET_CONTAINER" ]; then
    echo "Usage: $0 <container-id>"
    exit 1
fi

# Check if image exists, build if not
if ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "🔧 Building debug-toolbox (first time)..."
    cd "$DOCKERFILE_DIR"
    docker build -t "$IMAGE" --build-arg DOTFILES="${DOTFILES:-$HOME/.dotfiles}" .
fi

# Run debug container attached to target
exec docker run -it --rm \
    --pid=container:"$TARGET_CONTAINER" \
    --net=container:"$TARGET_CONTAINER" \
    --volumes-from "$TARGET_CONTAINER" \
    "$IMAGE"
