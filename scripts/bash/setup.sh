#!/usr/bin/env bash
# setup.sh — Install all required toolchain for Cloud-Azure-Platform-Management
# Supports: macOS (Homebrew), Ubuntu/Debian, and WSL2
set -euo pipefail

echo "=== Cloud-Azure-Platform-Management — Toolchain Setup ==="
echo "Platform: $(uname -s) | Date: $(date)"

OS=$(uname -s)

install_brew_package() {
    if ! brew list "$1" &>/dev/null; then
        echo "  Installing $1..."
        brew install "$1"
    else
        echo "  $1 already installed ($(brew list --versions "$1"))"
    fi
}

# ─── Azure CLI ────────────────────────────────────────────────────────────────
echo ""
echo "[1/6] Azure CLI..."
if ! command -v az &>/dev/null; then
    if [ "$OS" = "Darwin" ]; then
        brew install azure-cli
    elif [ "$OS" = "Linux" ]; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    fi
else
    echo "  Azure CLI: $(az --version | head -1)"
fi

# ─── Bicep CLI ────────────────────────────────────────────────────────────────
echo ""
echo "[2/6] Bicep CLI..."
az bicep install 2>/dev/null || az bicep upgrade 2>/dev/null || true
echo "  Bicep: $(az bicep version 2>/dev/null || echo 'installed')"

# ─── Terraform ───────────────────────────────────────────────────────────────
echo ""
echo "[3/6] Terraform..."
if ! command -v terraform &>/dev/null; then
    if [ "$OS" = "Darwin" ]; then
        brew tap hashicorp/tap && brew install hashicorp/tap/terraform
    elif [ "$OS" = "Linux" ]; then
        wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
        sudo apt update && sudo apt install -y terraform
    fi
else
    echo "  Terraform: $(terraform version | head -1)"
fi

# ─── Checkov ─────────────────────────────────────────────────────────────────
echo ""
echo "[4/6] Checkov (IaC security scanner)..."
if ! command -v checkov &>/dev/null; then
    pip3 install checkov --quiet
else
    echo "  Checkov: $(checkov --version 2>/dev/null || echo 'installed')"
fi

# ─── PowerShell ──────────────────────────────────────────────────────────────
echo ""
echo "[5/6] PowerShell 7+..."
if ! command -v pwsh &>/dev/null; then
    if [ "$OS" = "Darwin" ]; then
        brew install --cask powershell
    elif [ "$OS" = "Linux" ]; then
        sudo apt install -y powershell 2>/dev/null || \
        snap install powershell --classic 2>/dev/null || \
        echo "  Skipping PowerShell (install manually from https://aka.ms/powershell)"
    fi
else
    echo "  PowerShell: $(pwsh --version)"
fi

# ─── Az PowerShell Modules ────────────────────────────────────────────────────
echo ""
echo "[6/6] Az PowerShell modules..."
if command -v pwsh &>/dev/null; then
    pwsh -Command "
        if (-not (Get-Module -ListAvailable Az.Accounts)) {
            Write-Host '  Installing Az PowerShell modules...'
            Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
            Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
        } else {
            Write-Host '  Az PowerShell modules already installed'
        }
    "
else
    echo "  Skipping (PowerShell not available)"
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. az login"
echo "  2. az account set --subscription <management-subscription-id>"
echo "  3. pwsh scripts/powershell/Setup-Governance.ps1 -TenantId <tenant-id> -RootMgId <root-mg-id>"
