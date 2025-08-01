#!/bin/bash

# Cursor WSL Isolation - WSL Setup Script
# This script sets up Nix and prepares WSL for isolated Cursor environments

set -e  # Exit on any error

echo "🐧 Cursor WSL Isolation Setup"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in WSL
if [[ ! -f /proc/version ]] || ! grep -q Microsoft /proc/version; then
    print_error "This script must be run in WSL"
    exit 1
fi

print_status "Starting WSL setup for Cursor isolation..."

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
print_status "Installing required packages..."
sudo apt install -y curl wget git build-essential

# Install Nix
print_status "Installing Nix package manager..."
if ! command -v nix &> /dev/null; then
    sh <(curl -L https://nixos.org/nix/install) --daemon
    . ~/.nix-profile/etc/profile.d/nix.sh
    echo "source ~/.nix-profile/etc/profile.d/nix.sh" >> ~/.bashrc
    echo "source ~/.nix-profile/etc/profile.d/nix.sh" >> ~/.profile
    print_success "Nix installed successfully"
else
    print_success "Nix is already installed"
fi

# Enable Nix flakes
print_status "Enabling Nix flakes..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Install Cursor
print_status "Installing Cursor editor..."
CURSOR_URL="https://download.cursor.so/linux/appImage/x64"
CURSOR_DEB="/tmp/cursor.deb"

if ! command -v cursor &> /dev/null; then
    wget -O "$CURSOR_DEB" "$CURSOR_URL"
    sudo dpkg -i "$CURSOR_DEB" || sudo apt-get install -f -y
    rm "$CURSOR_DEB"
    print_success "Cursor installed successfully"
else
    print_success "Cursor is already installed"
fi

# Set up GUI forwarding
print_status "Setting up GUI forwarding..."
if [[ -z "$DISPLAY" ]]; then
    echo "export DISPLAY=:0" >> ~/.bashrc
    echo "export DISPLAY=:0" >> ~/.profile
    print_success "DISPLAY variable configured"
fi

# Create isolation directories
print_status "Creating isolation directories..."
mkdir -p ~/cursor-environments
mkdir -p ~/cursor-projects

# Test GUI forwarding
print_status "Testing GUI forwarding..."
if xset q &>/dev/null; then
    print_success "GUI forwarding is working"
else
    print_warning "GUI forwarding may not be working. Please check WSLg installation"
fi

print_success "WSL setup completed successfully!"
echo ""
echo "🎯 Next steps:"
echo "1. Create your first environment: ./cursor-wsl-iso.sh 1 python311"
echo "2. Or create a Node.js environment: ./cursor-wsl-iso.sh 2 node20"
echo "3. Or create a fullstack environment: ./cursor-wsl-iso.sh 3 fullstack"
echo ""
echo "💡 Each environment will be completely isolated with its own packages and settings!" 