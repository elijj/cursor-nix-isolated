# Cursor WSL Isolation

Run multiple isolated Cursor instances on Windows using WSL2.

## Quick Start

### 1. Setup
```bash
git clone https://github.com/yourusername/cursor-nix-isolated.git
cd cursor-nix-isolated

# Choose your setup method:
.\setup-windows.ps1        # PowerShell (recommended)
./setup-wsl.sh            # WSL
```

### 2. Create Environment
```bash
./cursor-wsl-iso.sh 1 python311
```

### 3. Start Coding
```bash
cursor /path/to/your/project
```

## Usage

### Environment Types
- `python311` - Python 3.11
- `node20` - Node.js 20
- `fullstack` - Python + Node.js + DB
- `general` - Basic tools

### Examples
```bash
# Python project
./cursor-wsl-iso.sh 1 python311

# Node.js project
./cursor-wsl-iso.sh 2 node20

# Fullstack project
./cursor-wsl-iso.sh 3 fullstack
```

### Commands (inside environment)
```bash
cursor [workspace]     # Launch VS Code with isolated environment
cursor_env_info        # Show details
cursor_env_clean       # Remove environment
cursor_env_backup [name] # Backup environment
exit                   # Leave environment
```

## What You Get

✅ **Complete Isolation** - Each environment is completely separate  
✅ **No Conflicts** - Different Python/Node versions per environment  
✅ **Docker Isolation** - Separate Docker contexts per environment  
✅ **Git Isolation** - Different Git identities per environment  
✅ **Easy Cleanup** - Remove entire environment with one command  

## Prerequisites

- Windows 10/11
- WSL2 enabled
- Virtualization enabled in BIOS

### Enable WSL2
```powershell
# Run as Administrator
wsl --install
wsl --set-default-version 2
```

## Troubleshooting

**WSL not starting**
```powershell
wsl --shutdown
wsl
```

**Cursor not launching**
```bash
echo $DISPLAY  # Should show :0
```

**PowerShell execution policy**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Script not working**
```bash
# Check if you're in WSL
cat /proc/version

# Should show "Microsoft" or "WSL" in the output
```

## Files

- `setup-windows.ps1` - PowerShell setup
- `setup-wsl.sh` - WSL setup
- `cursor-wsl-iso.sh` - Main isolation script
- `LICENSE` - MIT License
- `.gitignore` - Git ignore rules

---

**Goal**: Fresh Windows → Isolated Cursor environments in 20 minutes! 🎯 