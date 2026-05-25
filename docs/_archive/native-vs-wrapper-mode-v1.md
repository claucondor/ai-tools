# NATIVE vs WRAPPER Mode

JanusToken operates in one of two modes selected at deployment. This decision is irreversible.

## Decision tree

```
Do you have an existing ERC-20 you want to add privacy to?
├── Yes → WRAPPER mode
│         (users call wrap/unwrap to enter/exit the confidential layer)
│
└── No — Are you issuing a new token from scratch?
    ├── Yes → NATIVE mode
    │         (you control supply via mintXY/burnXY)
    └── Maybe → Consider NATIVE mode if no underlying is needed;
                WRAPPER if you plan to migrate from a plain ERC-20 later
```

## Comparison

| Feature | NATIVE | WRAPPER |
|---------|--------|---------|
| Supply control | Owner only (mintXY/burnXY) | Locked via wrap/unwrap |
| Underlying ERC-20 | None | Required at deploy time |
| User entry | Owner mints to them | User calls wrap + approve |
| User exit | Owner burns from them | User calls unwrap |
| Total supply verification | totalSupplyCommitment() | Sum of locked underlying |
| Use case | New privacy token, grants | Privacy layer on existing ERC-20 |

## WRAPPER mode: the entry/exit flow

```
User (ERC-20 holder)
  1. ERC-20.approve(janusTokenAddress, amount)
  2. JanusToken.wrap(amount, {x: cx, y: cy})
     → ERC-20 locked in JanusToken contract
     → commitment recorded in user's slot
  ...confidential transfers...
  3. JanusToken.unwrap(from, amount, {x: cx, y: cy})  ← owner/bridge only
     → ERC-20 released to recipient
     → commitment burned from slot
```

## NATIVE mode: the mint/burn flow

```
Owner (protocol contract)
  1. JanusToken.mintXY(to, cx, cy)
     → commitment added to recipient's slot
  ...confidential transfers...
  2. JanusToken.burnXY(from, cx, cy)
     → commitment removed from sender's slot
```

## JanusFlow is WRAPPER mode for native FLOW

JanusFlow wraps Cadence's native FLOW token. It is conceptually WRAPPER mode but implemented at the Cadence layer (the EVM JanusToken instance it uses is in NATIVE mode, controlled by JanusFlow). This distinction matters when reading total supply — use `JanusFlow.getCommitment()` rather than the EVM `totalSupplyCommitment()`.

## If you are unsure

Start with WRAPPER mode. It is the safer default because:
- Users can exit to real tokens at any time
- You do not need to solve key management for minting rights
- It is composable with existing DeFi protocols
