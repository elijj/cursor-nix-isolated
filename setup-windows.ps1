# Cursor WSL Isolation - Windows PowerShell Setup Script
# This script sets up WSL2, Ubuntu, Nix, and GUI forwarding for Cursor

param(
    [switch]$Force,
    [switch]$SkipWSL,
    [switch]$SkipNix,
    [switch]$Verbose
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Cyan = "Cyan"

# Function to print colored output
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor $Cyan
    Write-Host ("=" * $Message.Length) -ForegroundColor $Cyan
}

# Check if running as Administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-Header "Cursor WSL Isolation Setup"
Write-Host "This script will set up WSL2, Ubuntu, Nix, and prepare your system for isolated Cursor environments.`n"

# Check if running as Administrator for WSL operations
$isAdmin = Test-Administrator
if (-not $isAdmin) {
    Write-Warning "Some operations require Administrator privileges."
    Write-Host "If you encounter permission errors, run PowerShell as Administrator.`n"
}

# Step 1: Check and enable WSL2
Write-Header "Step 1: Setting up WSL2"

if (-not $SkipWSL) {
    Write-Status "Checking WSL availability..."
    
    try {
        $wslVersion = wsl --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL is available"
        } else {
            throw "WSL not available"
        }
    }
    catch {
        Write-Error "WSL is not available. Please enable WSL2 first:"
        Write-Host "1. Open PowerShell as Administrator"
        Write-Host "2. Run: wsl --install"
        Write-Host "3. Restart your computer"
        Write-Host "4. Run this script again"
        exit 1
    }

    # Check WSL version
    Write-Status "Checking WSL version..."
    $wslVersionOutput = wsl --version 2>$null
    if ($wslVersionOutput -match "WSL version (\d+)") {
        $wslVersion = $matches[1]
        if ($wslVersion -eq "1") {
            Write-Warning "WSL1 detected. Upgrading to WSL2..."
            wsl --set-default-version 2
            Write-Success "WSL2 set as default"
        } else {
            Write-Success "WSL2 is available (version $wslVersion)"
        }
    } else {
        Write-Success "WSL2 is available"
    }

    # Check if Ubuntu is installed
    Write-Status "Checking for Ubuntu installation..."
    $distributions = wsl -l -v 2>$null
    if ($distributions -match "Ubuntu") {
        Write-Success "Ubuntu is already installed"
        
        # Check if Ubuntu is running WSL2
        if ($distributions -match "Ubuntu.*2") {
            Write-Success "Ubuntu is running WSL2"
        } else {
            Write-Warning "Ubuntu is running WSL1. Converting to WSL2..."
            wsl --set-version Ubuntu 2
            Write-Success "Ubuntu converted to WSL2"
        }
    } else {
        Write-Warning "Ubuntu not found. Installing Ubuntu..."
        wsl --install -d Ubuntu
        Write-Success "Ubuntu installation initiated"
        Write-Warning "Please complete Ubuntu setup in the new window, then run this script again"
        exit 0
    }
} else {
    Write-Status "Skipping WSL setup as requested"
}

# Step 2: Prepare WSL environment
Write-Header "Step 2: Preparing WSL Environment"

Write-Status "Starting Ubuntu and running Nix setup..."
$wslSetupScript = @'
set -e

echo "Ubuntu Setup Starting..."
echo "======================="

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y curl wget git build-essential

# Install Nix
echo "Installing Nix package manager..."
if ! command -v nix &> /dev/null; then
    sh <(curl -L https://nixos.org/nix/install) --daemon
    . ~/.nix-profile/etc/profile.d/nix.sh
    echo "source ~/.nix-profile/etc/profile.d/nix.sh" >> ~/.bashrc
    echo "source ~/.nix-profile/etc/profile.d/nix.sh" >> ~/.profile
    echo "Nix installed successfully"
else
    echo "Nix is already installed"
fi

# Enable Nix flakes
echo "Enabling Nix flakes..."
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# Install Cursor
echo "Installing Cursor editor..."
CURSOR_URL="https://download.cursor.so/linux/appImage/x64"
CURSOR_DEB="/tmp/cursor.deb"

if ! command -v cursor &> /dev/null; then
    wget -O "$CURSOR_DEB" "$CURSOR_URL"
    sudo dpkg -i "$CURSOR_DEB" || sudo apt-get install -f -y
    rm "$CURSOR_DEB"
    echo "Cursor installed successfully"
else
    echo "Cursor is already installed"
fi

# Set up GUI forwarding
echo "Setting up GUI forwarding..."
if [[ -z "$DISPLAY" ]]; then
    echo "export DISPLAY=:0" >> ~/.bashrc
    echo "export DISPLAY=:0" >> ~/.profile
    echo "DISPLAY variable configured"
fi

# Create isolation directories
echo "Creating isolation directories..."
mkdir -p ~/cursor-environments
mkdir -p ~/cursor-projects

# Test GUI forwarding
echo "Testing GUI forwarding..."
if xset q &>/dev/null; then
    echo "GUI forwarding is working"
else
    echo "GUI forwarding may not be working. Please check WSLg installation"
fi

echo "Ubuntu setup completed successfully!"
echo "You can now use ./cursor-wsl-iso.sh to create isolated environments"
'@

# Run the setup script in WSL
$wslSetupScript | wsl -d Ubuntu bash

if ($LASTEXITCODE -eq 0) {
    Write-Success "WSL environment setup completed"
} else {
    Write-Error "WSL environment setup failed"
    exit 1
}

# Step 3: Copy scripts to WSL
Write-Header "Step 3: Setting up Scripts"

Write-Status "Copying scripts to WSL..."
$currentDir = Get-Location

# Copy the isolation script to WSL
$cursorScript = Get-Content "cursor-wsl-iso.sh" -Raw
$cursorScript | wsl -d Ubuntu bash -c "cat > ~/cursor-wsl-iso.sh"
wsl -d Ubuntu chmod +x ~/cursor-wsl-iso.sh

Write-Success "Scripts copied to WSL"

# Step 4: Test the setup
Write-Header "Step 4: Testing Setup"

Write-Status "Testing WSL connection..."
$testResult = wsl -d Ubuntu echo "WSL connection successful"
if ($testResult -eq "WSL connection successful") {
    Write-Success "WSL connection working"
} else {
    Write-Error "WSL connection failed"
    exit 1
}

Write-Status "Testing Nix installation..."
$nixTest = wsl -d Ubuntu bash -c "source ~/.nix-profile/etc/profile.d/nix.sh && nix --version"
if ($nixTest -match "nix \(Nix\)") {
    Write-Success "Nix is working"
} else {
    Write-Warning "Nix may not be properly installed"
}

Write-Status "Testing Cursor installation..."
$cursorTest = wsl -d Ubuntu which cursor
if ($cursorTest) {
    Write-Success "Cursor is available"
} else {
    Write-Warning "Cursor may not be properly installed"
}

# Step 5: Final instructions
Write-Header "Setup Complete!"

Write-Success "Your system is now ready for isolated Cursor environments!"
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Open WSL Ubuntu: wsl -d Ubuntu"
Write-Host "2. Create your first environment: ./cursor-wsl-iso.sh 1 python311"
Write-Host "3. Or create a Node.js environment: ./cursor-wsl-iso.sh 2 node20"
Write-Host "4. Or create a fullstack environment: ./cursor-wsl-iso.sh 3 fullstack"
Write-Host ""
Write-Host "Each environment will be completely isolated with its own packages and settings!"
Write-Host ""
Write-Host "For detailed examples, see: examples.md"
Write-Host "For troubleshooting, see the troubleshooting section in README.md" 