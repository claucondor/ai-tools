#!/usr/bin/env bash
# install.sh — one-liner installer for openjanus/ai-tools plugin
#
# Usage:
#   sh -ci "$(curl -fsSL https://raw.githubusercontent.com/openjanus/ai-tools/main/scripts/install.sh)"
#
# What this does:
#   1. Adds the openjanus/ai-tools marketplace to Claude Code
#   2. Installs the openjanus plugin

set -euo pipefail

echo "Installing openjanus/ai-tools plugin for Claude Code..."

# Add marketplace
claude plugin marketplace add openjanus/ai-tools 2>/dev/null || {
  echo "Marketplace already added or claude not in PATH — skipping."
}

# Install plugin
claude plugin install openjanus@openjanus-ai-tools 2>/dev/null || {
  echo "Plugin already installed or install failed — try manually:"
  echo "  /plugin marketplace add openjanus/ai-tools"
  echo "  /plugin install openjanus@openjanus-ai-tools"
  exit 1
}

echo ""
echo "Done! The following skills are now available in Claude Code:"
echo "  openjanus-sdk        — @openjanus/sdk installation and usage"
echo "  openjanus-primitives — BabyJubJub, Pedersen, Groth16 reference"
echo "  openjanus-tokens     — JanusToken / JanusFlow contracts"
echo "  openjanus-deploy     — Deploying new JanusToken instances"
echo ""
echo "Documentation: https://github.com/openjanus/ai-tools/tree/main/docs"
