#!/bin/bash
set -e

# Usage: ./scripts/deploy.sh [web|server|all]
# Defaults to "all" if no argument provided.
#
# Prerequisites:
#   - SSH config alias "digitalocean" pointing to the server
#   - Git push access to qizheYang/rehydratedwater.com
#   - Dart SDK installed on the remote server
#   - guandan-server systemd service configured on the remote server

MODE="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Build metadata
BUILD_VERSION="1.0.0.$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo 0)"
BUILD_TIME="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo "=== Guan Dan Deploy ==="
echo "Mode: $MODE"
echo "Version: $BUILD_VERSION"
echo ""

deploy_web() {
    echo "--- Deploying web client ---"

    cd "$PROJECT_DIR"

    # Build Flutter web with production WS URL
    flutter build web \
        --base-href "/guandan/" \
        --release \
        --dart-define=WS_URL=wss://rehydratedwater.com/guandan-ws \
        --dart-define=BUILD_VERSION="$BUILD_VERSION"

    echo "Web build complete."

    # Clone or update the target repo
    DEPLOY_DIR="/tmp/rehydratedwater-deploy"
    if [ -d "$DEPLOY_DIR" ]; then
        cd "$DEPLOY_DIR"
        git pull origin main
    else
        git clone https://github.com/qizheYang/rehydratedwater.com.git "$DEPLOY_DIR"
        cd "$DEPLOY_DIR"
    fi

    # Copy built output
    rm -rf guandan
    cp -r "$PROJECT_DIR/build/web" guandan

    # Commit and push
    git add guandan
    git commit -m "Deploy guandan v$BUILD_VERSION" || echo "No changes"
    git push origin main

    echo "Web deployed. Webhook will auto-sync to server."
}

deploy_server() {
    echo "--- Deploying server ---"

    SSH_HOST="digitalocean"
    REMOTE_DIR="/var/www/guandan-server"

    # Upload server files
    echo "Uploading server files..."
    ssh "$SSH_HOST" "mkdir -p $REMOTE_DIR/lib $REMOTE_DIR/bin $REMOTE_DIR/shared/lib/models $REMOTE_DIR/shared/lib/protocol $REMOTE_DIR/shared/lib/engine"

    # Copy shared package
    scp "$PROJECT_DIR/shared/pubspec.yaml" "$SSH_HOST:$REMOTE_DIR/shared/"
    scp "$PROJECT_DIR/shared/lib/guandan_shared.dart" "$SSH_HOST:$REMOTE_DIR/shared/lib/"
    scp "$PROJECT_DIR"/shared/lib/models/*.dart "$SSH_HOST:$REMOTE_DIR/shared/lib/models/"
    scp "$PROJECT_DIR"/shared/lib/protocol/*.dart "$SSH_HOST:$REMOTE_DIR/shared/lib/protocol/"
    scp "$PROJECT_DIR"/shared/lib/engine/*.dart "$SSH_HOST:$REMOTE_DIR/shared/lib/engine/"

    # Copy server package
    scp "$PROJECT_DIR/server/bin/server.dart" "$SSH_HOST:$REMOTE_DIR/bin/"
    scp "$PROJECT_DIR"/server/lib/*.dart "$SSH_HOST:$REMOTE_DIR/lib/"

    # Upload server pubspec with fixed path
    sed 's|path: ../shared|path: shared|' "$PROJECT_DIR/server/pubspec.yaml" | \
        ssh "$SSH_HOST" "cat > $REMOTE_DIR/pubspec.yaml"

    # Compile and restart on remote
    echo "Compiling and restarting on server..."
    ssh "$SSH_HOST" "cd $REMOTE_DIR && dart pub get && dart compile exe bin/server.dart -o bin/guandan_server_new && mv bin/guandan_server_new bin/guandan_server && sudo systemctl restart guandan-server"

    echo "Server deployed and restarted."
}

case "$MODE" in
    web)    deploy_web ;;
    server) deploy_server ;;
    all)    deploy_web; deploy_server ;;
    *)      echo "Usage: $0 [web|server|all]"; exit 1 ;;
esac

echo ""
echo "=== Deploy complete ==="
echo "Web:    https://rehydratedwater.com/guandan/"
echo "Server: wss://rehydratedwater.com/guandan-ws"
