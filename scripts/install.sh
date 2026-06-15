#!/usr/bin/env bash
# install.sh — one-liner installer for openjanus/ai-tools plugin
#
# Usage:
#   sh -ci "$(curl -fsSL https://raw.githubusercontent.com/openjanus/ai-tools/main/scripts/install.sh)"
#
# What this does:
#   1. Adds the openjanus/ai-tools marketplace to the agent runtime
#   2. Installs the openjanus plugin

set -euo pipefail

echo "Installing openjanus/ai-tools plugin..."

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
echo "Done! The following skills are now available:"
echo "  openjanus-sdk        — @claucondor/sdk v0.8.2, ShieldedInbox/Checkpoint, batchClaim"
echo "  openjanus-primitives — BabyJubJub, Pedersen (@openjanus/commitment), Groth16 reference"
echo "  openjanus-tokens     — JanusFlow / JanusERC20 / JanusFT contracts"
echo "  openjanus-elgamal    — ECIES ShieldedNote encryption, BabyJub keypair derivation"
echo "  openjanus-deploy     — Deploying new JanusToken instances, v0.8.2 canonical addresses"
echo ""
echo "Documentation: https://github.com/openjanus/ai-tools/tree/main/plugins/openjanus/skills"
