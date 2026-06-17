# Windows Setup Script for SDD Agentic Framework
# Automatically installs all dependencies and sets up the framework
# Run this script in PowerShell: .\setup-windows.ps1

param(
    [switch]$SkipClaudeCode,
    [switch]$SkipGit,
    [switch]$SkipNode
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Success { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Warning { Write-Host "[WARNING] $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "[ERROR] $args" -ForegroundColor Red }

Write-Info "========================================="
Write-Info "   SDD Framework Windows Setup"
Write-Info "========================================="
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Not running as Administrator. Some installations may require elevation."
    Write-Info "If installations fail, right-click PowerShell and select 'Run as Administrator'"
    Write-Host ""
}

# Function to check if command exists
function Test-Command {
    param($Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to download and install from URL
function Install-FromUrl {
    param(
        [string]$Url,
        [string]$Name,
        [string]$OutFile
    )

    Write-Info "Downloading $Name..."
    try {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        Write-Success "$Name downloaded"

        Write-Info "Installing $Name..."
        Write-Warning "Please follow the installer prompts. Accept default options."
        Start-Process -FilePath $OutFile -Wait
        Write-Success "$Name installation completed"

        # Clean up installer
        Remove-Item $OutFile -Force
        return $true
    }
    catch {
        Write-Error "Failed to install $Name : $_"
        return $false
    }
}

# Step 1: Check and install Git for Windows
Write-Info "[Step 1/4] Checking Git installation..."
if (-not $SkipGit) {
    if (Test-Command git) {
        $gitVersion = git --version
        Write-Success "Git already installed: $gitVersion"
    }
    else {
        Write-Warning "Git not found. Installing Git for Windows (includes Git Bash)..."
        $gitInstaller = "$env:TEMP\Git-Setup.exe"
        $gitUrl = "https://github.com/git-for-windows/git/releases/download/v2.43.0.windows.1/Git-2.43.0-64-bit.exe"

        if (Install-FromUrl -Url $gitUrl -Name "Git for Windows" -OutFile $gitInstaller) {
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            if (Test-Command git) {
                Write-Success "Git installed successfully"
            }
            else {
                Write-Warning "Git installed but not in PATH. You may need to restart PowerShell."
            }
        }
    }
}
else {
    Write-Warning "Skipping Git installation (--SkipGit flag)"
}

Write-Host ""

# Step 2: Check and install Node.js
Write-Info "[Step 2/4] Checking Node.js installation..."
if (-not $SkipNode) {
    if (Test-Command node) {
        $nodeVersion = node --version
        $npmVersion = npm --version
        Write-Success "Node.js already installed: $nodeVersion"
        Write-Success "npm already installed: v$npmVersion"

        # Check version requirement
        $nodeMajorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
        if ($nodeMajorVersion -lt 18) {
            Write-Warning "Node.js version is below v18. Consider upgrading."
            Write-Info "Download from: https://nodejs.org/"
        }
    }
    else {
        Write-Warning "Node.js not found. Installing Node.js v20 LTS..."
        $nodeInstaller = "$env:TEMP\node-Setup.msi"
        $nodeUrl = "https://nodejs.org/dist/v20.11.0/node-v20.11.0-x64.msi"

        if (Install-FromUrl -Url $nodeUrl -Name "Node.js" -OutFile $nodeInstaller) {
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            if (Test-Command node) {
                $nodeVersion = node --version
                $npmVersion = npm --version
                Write-Success "Node.js installed: $nodeVersion"
                Write-Success "npm installed: v$npmVersion"
            }
            else {
                Write-Warning "Node.js installed but not in PATH. Please restart PowerShell and run this script again."
                exit 1
            }
        }
    }
}
else {
    Write-Warning "Skipping Node.js installation (--SkipNode flag)"
}

Write-Host ""

# Step 3: Check and install Claude Code CLI
Write-Info "[Step 3/4] Checking Claude Code installation..."
if (-not $SkipClaudeCode) {
    if (Test-Command claude) {
        Write-Success "Claude Code CLI already installed"

        # Check if logged in
        try {
            $claudeStatus = claude --version 2>&1
            Write-Success "Claude Code version: $claudeStatus"
        }
        catch {
            Write-Warning "Claude Code installed but may need login"
        }
    }
    else {
        Write-Warning "Claude Code CLI not found"
        Write-Info "Attempting to install Claude Code via npm..."
        Write-Host ""

        $claudeInstalled = $false

        # Try npm global install
        if (Test-Command npm) {
            try {
                Write-Info "Running: npm install -g @anthropic-ai/claude-code"
                npm install -g @anthropic-ai/claude-code 2>&1 | Out-Null

                # Refresh PATH
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                if (Test-Command claude) {
                    Write-Success "Claude Code installed successfully via npm"
                    $claudeInstalled = $true
                }
            }
            catch {
                Write-Warning "npm installation failed"
            }
        }

        if (-not $claudeInstalled) {
            Write-Host ""
            Write-Warning "Automatic installation failed. Please install manually:"
            Write-Host ""
            Write-Info "========================================="
            Write-Info "     CLAUDE CODE INSTALLATION OPTIONS"
            Write-Info "========================================="
            Write-Host ""
            Write-Host "Option 1: npm (Recommended)" -ForegroundColor Yellow
            Write-Host "  npm install -g @anthropic-ai/claude-code" -ForegroundColor Green
            Write-Host ""
            Write-Host "Option 2: Direct Download" -ForegroundColor Yellow
            Write-Host "  Visit: https://claude.ai/code" -ForegroundColor Green
            Write-Host "  Follow Windows installation instructions"
            Write-Host ""
            Write-Host "After installation:" -ForegroundColor Yellow
            Write-Host "  claude login" -ForegroundColor Green
            Write-Host ""
            Write-Info "========================================="
            Write-Host ""

            $continue = Read-Host "Press Enter to continue setup, or Ctrl+C to install Claude Code first"
        }
        else {
            # Prompt for login
            Write-Host ""
            Write-Info "Please authenticate Claude Code:"
            Write-Host "  Run: " -NoNewline
            Write-Host "claude login" -ForegroundColor Green
            Write-Host ""
            $loginNow = Read-Host "Would you like to login now? (y/n)"
            if ($loginNow -eq "y" -or $loginNow -eq "Y") {
                try {
                    claude login
                }
                catch {
                    Write-Warning "Login skipped or failed. Run 'claude login' later."
                }
            }
        }
    }
}
else {
    Write-Warning "Skipping Claude Code installation (--SkipClaudeCode flag)"
}

Write-Host ""

# Step 4: Run framework setup
Write-Info "[Step 4/4] Setting up SDD Framework..."
Write-Host ""

# Check if we have Git Bash available
$gitBashPath = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $gitBashPath) {
    Write-Info "Using Git Bash to run setup script..."
    & $gitBashPath -c "cd '$PWD' && ./.logic-loom/scripts/setup.sh"
}
elseif (Test-Command bash) {
    Write-Info "Using bash to run setup script..."
    bash ./.logic-loom/scripts/setup.sh
}
else {
    Write-Warning "Bash not found. Attempting to run setup manually..."

    # Manual setup steps
    if (Test-Command node) {
        Write-Info "Installing npm dependencies..."
        npm install
        Write-Success "Dependencies installed"
    }

    if (Test-Path ".env.example" -and -not (Test-Path ".env")) {
        Write-Info "Creating .env file..."
        Copy-Item ".env.example" ".env"
        Write-Success ".env file created"
    }

    Write-Success "Manual setup completed"
}

Write-Host ""
Write-Success "========================================="
Write-Success "   Setup Complete! 🎉"
Write-Success "========================================="
Write-Host ""

Write-Info "Next steps:"
Write-Host ""
Write-Info "1. RECOMMENDED: Create a Product Requirements Document (PRD)"
Write-Info "   The PRD serves as your Single Source of Truth (SSOT)"
Write-Host ""
Write-Info "   To create a PRD, open Claude Code and run:"
Write-Host "   " -NoNewline
Write-Host "/create-prd" -ForegroundColor Yellow
Write-Host ""
Write-Info "2. Customize the constitution for your project:"
Write-Host "   " -NoNewline
Write-Host ".specify\memory\constitution.md" -ForegroundColor Yellow
Write-Host ""
Write-Info "3. Create your first feature specification:"
Write-Host "   Open Claude Code and run: " -NoNewline
Write-Host "/specify" -ForegroundColor Yellow
Write-Host ""

# Offer to launch Claude Code
if (Test-Command claude) {
    Write-Host ""
    $launch = Read-Host "Would you like to launch Claude Code now? (y/n)"
    if ($launch -eq "y" -or $launch -eq "Y") {
        Write-Info "Launching Claude Code..."
        claude code .
    }
}
else {
    Write-Warning "Claude Code CLI not available"
    Write-Info "Once installed, launch Claude Code with: claude code ."
}

Write-Host ""
Write-Info "For more information, see START_HERE.md"
Write-Host ""
