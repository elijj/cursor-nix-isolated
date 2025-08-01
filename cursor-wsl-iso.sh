#!/usr/bin/env bash

ENV_NUM=${1:-"1"}
PROJECT_TYPE=${2:-"general"}

echo "🚀 Starting Cursor environment: $ENV_NUM ($PROJECT_TYPE)"

# Check if we're in WSL
if [[ ! -f /proc/version ]] || ! grep -q -i "microsoft\|wsl" /proc/version; then
    echo "❌ This script must be run in WSL (Windows Subsystem for Linux)"
    echo "Please run: wsl -d Ubuntu"
    exit 1
fi

# Create isolated environment root
export ENV_ROOT="$HOME/.cursor-environments/$ENV_NUM"
export ISOLATED_HOME="$ENV_ROOT/home"
export ISOLATED_CACHE="$ENV_ROOT/cache"
export ISOLATED_CONFIG="$ENV_ROOT/config"
export ISOLATED_DATA="$ENV_ROOT/data"

# Create directory structure
mkdir -p "$ISOLATED_HOME" "$ISOLATED_CACHE" "$ISOLATED_CONFIG" "$ISOLATED_DATA"
mkdir -p "$ISOLATED_HOME/.local/bin"

# Save original environment
export OLD_PATH="$PATH"
export OLD_HOME="$HOME"
export OLD_PYTHONPATH="$PYTHONPATH"
export OLD_NODE_PATH="$NODE_PATH"

# Set up isolated environment
export HOME="$ISOLATED_HOME"
export PATH="$ISOLATED_HOME/.local/bin:$PATH"

# Language-specific isolation
export PYTHONPATH=""
export PIP_PREFIX="$ISOLATED_DATA/pip"
export PYTHONUSERBASE="$ISOLATED_DATA/pip"
export NPM_CONFIG_PREFIX="$ISOLATED_DATA/npm"
export NODE_PATH="$ISOLATED_DATA/npm/lib/node_modules"
export NPM_CONFIG_CACHE="$ISOLATED_CACHE/npm"

# Editor isolation
export VSCODE_PORTABLE="$ISOLATED_DATA/vscode"

# Git isolation (separate identity per environment)
export GIT_CONFIG_GLOBAL="$ISOLATED_CONFIG/git/config"
mkdir -p "$ISOLATED_CONFIG/git"

# Docker isolation
export DOCKER_CONFIG="$ISOLATED_CONFIG/docker"
export COMPOSE_PROJECT_NAME="cursor-env-$ENV_NUM"
export DOCKER_BUILDKIT_PROGRESS="plain"
mkdir -p "$DOCKER_CONFIG"

# X11 setup for GUI
export DISPLAY=${DISPLAY:-:0}
export LIBGL_ALWAYS_INDIRECT=1

# Create all necessary directories
mkdir -p "$PIP_PREFIX" "$NPM_CONFIG_PREFIX" "$VSCODE_PORTABLE" "$DOCKER_CONFIG"
mkdir -p "$ISOLATED_CACHE/npm"

# Setup Docker context isolation
setup_docker_isolation() {
    # Check if Docker daemon is accessible
    if docker info >/dev/null 2>&1; then
        # Create isolated Docker context if it doesn't exist
        if ! docker context ls --format "{{.Name}}" | grep -q "^cursor-$ENV_NUM$"; then
            echo "🐳 Setting up Docker context for environment $ENV_NUM..."
            docker context create "cursor-$ENV_NUM" \
                --description "Cursor environment $ENV_NUM" \
                --docker "host=unix:///var/run/docker.sock" 2>/dev/null || true
        fi
        
        # Use the isolated context
        docker context use "cursor-$ENV_NUM" 2>/dev/null || true
        echo "🐳 Docker context 'cursor-$ENV_NUM' active"
    else
        echo "⚠️  Docker daemon not running. Docker commands will not work."
        echo "💡 Start Docker with: sudo systemctl start docker (or use Docker Desktop)"
    fi
}

# Setup docker on first run
setup_docker_isolation

# Enhanced cursor command (using VS Code as Cursor alternative)
cursor() {
    local workspace="${1:-.}"
    
    # Use VS Code with isolated settings
    code --user-data-dir="$ISOLATED_DATA/vscode" --extensions-dir="$ISOLATED_DATA/vscode/extensions" "$workspace" &
    
    local cursor_pid=$!
    echo "🚀 VS Code launched in environment $ENV_NUM (PID: $cursor_pid)"
    echo "📁 Workspace: $workspace"
    echo "💾 Data: $ISOLATED_DATA/vscode"
}
export -f cursor

# Environment management commands
cursor_env_info() {
    echo "🔍 Environment $ENV_NUM ($PROJECT_TYPE) Info:"
    echo "🐍 Python: $(python3 --version 2>/dev/null || echo 'Not available')"
    echo "📦 Node: $(node --version 2>/dev/null || echo 'Not available')"
    echo "🐳 Docker: $(docker --version 2>/dev/null || echo 'Not available')"
    if docker info >/dev/null 2>&1; then
        echo "🐳 Docker Context: $(docker context show 2>/dev/null || echo 'default')"
        echo "🐳 Compose Project: $COMPOSE_PROJECT_NAME"
    fi
    echo "📁 Root: $ENV_ROOT"
    echo "💾 Data: $ISOLATED_DATA"
    echo "⚙️  Config: $ISOLATED_CONFIG"
    echo "🏠 Home: $ISOLATED_HOME"
}
export -f cursor_env_info

cursor_env_clean() {
    echo "🧹 Cleaning environment $ENV_NUM..."
    
    # Stop any running containers for this environment
    if docker info >/dev/null 2>&1; then
        echo "🐳 Stopping Docker containers for environment $ENV_NUM..."
        docker context use "cursor-$ENV_NUM" 2>/dev/null || true
        
        # Stop containers with our project name
        local containers=$(docker ps -q --filter "label=com.docker.compose.project=cursor-env-$ENV_NUM" 2>/dev/null)
        if [ -n "$containers" ]; then
            docker stop $containers 2>/dev/null || true
            docker rm $containers 2>/dev/null || true
        fi
        
        # Remove Docker context
        docker context use default 2>/dev/null || true
        docker context rm "cursor-$ENV_NUM" 2>/dev/null || true
        echo "🐳 Docker context 'cursor-$ENV_NUM' removed"
    fi
    
    # Remove environment directory
    rm -rf "$ENV_ROOT"
    echo "✅ Environment $ENV_NUM cleaned"
}
export -f cursor_env_clean

cursor_env_backup() {
    local backup_name="${1:-backup-$(date +%Y%m%d-%H%M%S)}"
    echo "💾 Backing up environment $ENV_NUM as $backup_name..."
    tar -czf "$HOME/.cursor-environments/$ENV_NUM-$backup_name.tar.gz" -C "$ENV_ROOT" .
    echo "✅ Backup saved: $HOME/.cursor-environments/$ENV_NUM-$backup_name.tar.gz"
}
export -f cursor_env_backup

# Welcome message
echo "🚀 Isolated development environment $ENV_NUM ($PROJECT_TYPE) loaded"
cursor_env_info
echo ""
echo "📋 Available commands:"
echo "  cursor [workspace]     - Launch VS Code with isolated environment"
echo "  cursor_env_info        - Show environment details"
echo "  cursor_env_clean       - Clean this environment"
echo "  cursor_env_backup [name] - Backup this environment"
echo "  exit                   - Leave this environment"
echo ""

# Cleanup function
cleanup() {
    # Switch back to default Docker context before cleanup
    if docker info >/dev/null 2>&1; then
        docker context use default 2>/dev/null || true
    fi
    
    export PATH="$OLD_PATH"
    export HOME="$OLD_HOME"
    export PYTHONPATH="$OLD_PYTHONPATH"
    export NODE_PATH="$OLD_NODE_PATH"
    unset PIP_PREFIX PYTHONUSERBASE NPM_CONFIG_PREFIX NPM_CONFIG_CACHE
    unset VSCODE_PORTABLE DISPLAY LIBGL_ALWAYS_INDIRECT GIT_CONFIG_GLOBAL
    unset DOCKER_CONFIG COMPOSE_PROJECT_NAME DOCKER_BUILDKIT_PROGRESS
    unset ENV_ROOT ISOLATED_HOME ISOLATED_CACHE ISOLATED_CONFIG ISOLATED_DATA
    unset OLD_PATH OLD_HOME OLD_PYTHONPATH OLD_NODE_PATH
}
trap cleanup EXIT

# Start interactive shell
echo "🔧 Starting isolated shell..."
exec bash