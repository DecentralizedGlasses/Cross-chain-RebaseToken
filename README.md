# Cross-Chain Rebase Token using Chainlink CCIP

**Author:** Sivaji (`DecentralizedGlasses`)  
**Tech Stack:** Solidity · Foundry · Chainlink CCIP  
**Project Type:** Advanced DeFi / Cross-Chain Token Prototype

---

## 📌 Overview

This project implements a **cross-chain rebasing ERC20 token** that can be securely transferred between multiple blockchains using **Chainlink CCIP (Cross-Chain Interoperability Protocol)**.

Unlike traditional bridge tokens, this system preserves **rebasing behavior across chains**, ensuring user balances remain mathematically correct after cross-chain transfers.

The project is designed to reflect **real-world DeFi architecture**, with proper separation of concerns, restricted minting, and professional-grade testing using **Foundry**, **local simulators**, and **forked networks**.

---

## 🎯 Project Goals

- Enable secure cross-chain token transfers using Chainlink CCIP
- Support rebasing (interest-based balance scaling)
- Maintain consistent token supply across chains
- Avoid repeated live testnet deployments
- Demonstrate production-style DeFi contract architecture

---

## 🧠 Why This Project Matters

Cross-chain rebasing tokens are complex because they must handle:

- Balance scaling (rebasing)
- Cross-chain state synchronization
- Secure mint/burn permissions
- Accurate supply accounting

This project demonstrates how these challenges can be solved using:

- Token Pool architecture
- Chainlink CCIP messaging
- Encoded rebasing metadata
- Controlled minting logic
- Fork-based testing strategies

---

## 🏗️ Architecture Overview

User
└── RebaseToken (ERC20 with rebasing)
└── RebaseTokenPool (per chain)
├── lockOrBurn() // source chain
├── releaseOrMint() // destination chain
└── Chainlink CCIP Router

Each blockchain contains:

- Its own `RebaseToken`
- Its own `RebaseTokenPool`
- CCIP routes configured between pools

---

## 📦 Core Contracts

### RebaseToken.sol

- ERC20-compatible token
- Supports interest-based rebasing
- Balances scale using a global interest rate
- Minting restricted to authorized TokenPools only

### RebaseTokenPool.sol

- Implements Chainlink CCIP token pool interface
- Handles:
  - `lockOrBurn()` on the source chain
  - `releaseOrMint()` on the destination chain
- Encodes and decodes rebasing metadata
- Enforces cross-chain permissions

### Vault.sol (Optional)

- Authorization or custody abstraction
- Isolates minting permissions from token logic

---

## 🔁 Cross-Chain Transfer Flow

### Source Chain

1. User initiates bridge transaction
2. Tokens are burned or locked
3. Rebasing metadata is encoded
4. CCIP message is sent to destination chain

### Destination Chain

1. CCIP message is received
2. Rebasing metadata is decoded
3. Tokens are minted or released
4. User receives rebased tokens

✔️ Supply consistency maintained  
✔️ Rebasing math preserved  
✔️ No trusted third party

---

## 🧪 Testing Strategy

The project uses **Foundry** for testing with:

- Local CCIP simulator tests
- Forked testnet testing (Sepolia ↔ Arbitrum Sepolia)
- Bridge flow validation
- Permission and role checks
- Rebasing correctness verification

This approach enables realistic testing without repeated live deployments.

---

## 📂 Project Structure

.
├── src/
│ ├── RebaseToken.sol
│ ├── RebaseTokenPool.sol
│ ├── Vault.sol
│
├── test/
│ ├── BridgeTest.t.sol
│ ├── RebaseTokenTest.t.sol
│ ├── ForkedBridgeTest.t.sol
│
├── script/
│ ├── Deploy.s.sol
│ ├── bridgeToZksync.sh
│
├── lib/
│ ├── forge-std
│ ├── chainlink
│
├── foundry.toml
├── .env
└── README.md

---

## 🚀 Running the Project Locally (Individual User)

### Prerequisites

- Git
- Foundry
- Node.js (optional)

Install Foundry:

````bash
curl -L https://foundry.paradigm.xyz | bash
foundryup


## 🚀 Running the Project Locally (Individual User)

### Clone the Repository

```bash
git clone https://github.com/rosarioborgesi/foundry-cross-chain-rebase-token.git
cd foundry-cross-chain-rebase-token
Install Dependencies
bash
Copy code
forge install
Environment Configuration
Create a .env file in the project root:

env
Copy code
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_rpc_url
ARBITRUM_SEPOLIA_RPC_URL=your_rpc_url
⚠️ Never commit private keys to GitHub.

Run Tests
Run all tests:

bash
Copy code
forge test -vvv
Run forked tests:

bash
Copy code
forge test --fork-url $SEPOLIA_RPC_URL -vvv
Deploy Contracts (Optional)
bash
Copy code
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY
Bridge Tokens Using Script
bash
Copy code
./bridgeToZksync.sh
This script deploys the required contracts, configures CCIP routes, and performs a sample cross-chain token transfer.

🔐 Security Notes
Minting is strictly restricted to TokenPools

Cross-chain messages are validated via Chainlink CCIP

No externally accessible admin minting

Not audited — for educational and testing purposes only

📚 Learning Outcomes
This project helps understand:

Chainlink CCIP internals

Cross-chain token pool architecture

Rebasing token mechanics

Secure mint/burn patterns

Professional DeFi testing workflows

🔮 Future Improvements
Multi-chain routing support

Gas optimizations

Formal verification

Frontend UI for bridging

Audit-ready hardening

👤 Author
Sivaji
Blockchain & Full-Stack Developer
GitHub: https://github.com/DecentralizedGlasses
````
