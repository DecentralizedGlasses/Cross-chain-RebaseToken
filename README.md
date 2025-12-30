# Cross-chain Rebase Token — Overview

A **cross-chain, interest-bearing ERC20 token** that:

- Mints **1:1** against ETH deposits into a vault
- Accrues interest **linearly over time** with a **per-user interest rate fixed at deposit time**
- Bridges across chains using **Chainlink CCIP**, preserving each user’s interest rate on the destination chain

This repository is a **Foundry-based project** demonstrating a **CCIP-enabled rebasing token** where the **global interest rate can only decrease**, rewarding early adopters while maintaining cross-chain yield fidelity.

---

## High-level Design

The system is composed of three core components:

- **Vault**: Accepts ETH deposits and handles minting/redemption
- **RebaseToken**: ERC20 token with dynamic balances based on linear interest accrual
- **RebaseTokenPool**: Chainlink CCIP integration layer enabling cross-chain transfers

Key properties:

- Interest is computed **on demand**, not via periodic rebases
- Each user’s interest rate is locked at mint time
- Cross-chain transfers preserve the user’s yield profile

---

## Contracts Overview

### Vault (`Vault.sol`)

- Accepts ETH deposits and mints rebase tokens **1:1** with deposited ETH
- Users can redeem rebase tokens for ETH
- Passing `type(uint256).max` redeems the full balance
- Emits `Deposit` and `Redeem` events for indexing and integrations

---

### Rebase Token (`RebaseToken.sol`)

ERC20 token with **dynamic `balanceOf`**.

**Balance formula**

```
balanceOf(user) = principal × (1 + r_user × Δt)
```

- Accrual is linear since the user’s last interaction
- No global rebases; interest is calculated lazily

**Interest model**

- **Global interest rate**
  - Stored as `s_interestRate`
  - Can only decrease over time
  - Controlled by the contract owner
- **Per-user interest rate**
  - Fixed at mint / deposit time
  - Does not change even if the global rate decreases

**Accrual triggers**

Interest is realized on:

- `mint` (vault deposits)
- `burn` (vault redemptions and cross-chain burns)
- `transfer` and `transferFrom` (sender and recipient)

**Access control**

- Uses `Ownable` + `AccessControl`
- `MINT_AND_BURN_ROLE` required for minting and burning
- Role granted to the Vault and RebaseTokenPool

---

### Rebase Token Pool (`RebaseTokenPool.sol`)

- Extends **Chainlink CCIP TokenPool**
- Enables cross-chain transfers of the rebasing token

**On lock / burn (source chain)**

- Burns tokens on the source chain
- Reads the user’s per-user interest rate
- Encodes the rate into `destPoolData`

**On release / mint (destination chain)**

- Decodes the interest rate
- Mints tokens with the same per-user rate
- Preserves the user’s yield profile across chains

---

## Cross-chain Flow (Example: Sepolia ↔ Base Sepolia)

1. **Deploy contracts on Base Sepolia**  
   RebaseToken and RebaseTokenPool are deployed and configured.

2. **Deploy contracts on Sepolia**  
   The same contracts are deployed on Sepolia.

3. **Deploy Vault on Sepolia**  
   Vault is initialized with the Sepolia RebaseToken address.

4. **Configure CCIP Pools**  
   Each RebaseTokenPool is configured to recognize its counterpart pool and token.

5. **Deposit & Accrue Interest**  
   Users deposit ETH into the Sepolia Vault, minting rebase tokens at the current global interest rate.

6. **Bridge Tokens via CCIP**  
   Tokens are bridged to Base Sepolia.  
   The user’s per-user interest rate is carried in the CCIP message and applied on the destination chain.

---

## Project Structure

.
├── src/
│ ├── RebaseToken.sol
│ ├── RebaseTokenPool.sol
│ └── Vault.sol
│
├── test/
│ ├── BridgeTest.t.sol
│ ├── RebaseTokenTest.t.sol
│ └── ForkedBridgeTest.t.sol
│
├── script/
│ ├── Deployer.s.sol
│ ├── ConfigurePool.s.sol
│ ├── BridgeTokens.s.sol
│ └── bridgeToZksync.sh
│
├── lib/
│ ├── forge-std/
│ └── chainlink/
│
├── foundry.toml
├── Makefile
├── .env
└── README.md

## Local Development

This project uses **Foundry**.

### Install Dependencies

```bash
make install

```

#### Build

```
make build
```

#### Run Tests

```
make test
```

#### Format

```
make format
```

#### Coverage

```
make coverage
```

#### Local Anvil Node

```
make anvil
```

### Deployment & Bridging

- Environment
- Create a .env file with at least:

```
SEPOLIA_RPC_URL=...
BASE_SEPOLIA_RPC_URL=...
ARBITRUM_SEPOLIA_RPC_URL=...   # optional, for testing
PRIVATE_KEY=...
```

## Scripts

- script/Deployer.s.sol
  Deploys RebaseToken, RebaseTokenPool, and Vault.

- script/ConfigurePool.s.sol
  Configures CCIP token pool connections across chains.

- script/BridgeTokens.s.sol
  Initiates a cross-chain transfer via CCIP.

## Convenience Script

```
chmod +x bridgeToZksync.sh
./bridgeToZksync.sh
```

# Key Ideas

##### Per-user fixed interest rate

- Each user’s rate is locked at deposit time and never changes.

##### Global rate can only decrease

- Early adopters benefit from higher yields.

##### Cross-chain fidelity

- Yield profiles are preserved when moving across chains.

##### Rebase via balanceOf

- Interest is computed lazily and settled on user actions, avoiding mass rebases.

### Pros and Cons

#### Pros

- Preserves user yield across chains
- No periodic rebases (gas-efficient)
- Rewards early adopters via decreasing global rate
- Clean separation of concerns (Vault, Token, Pool)
- Realistic CCIP-based cross-chain architecture

#### Cons

- Increased complexity compared to standard ERC20 tokens
- Cross-chain logic depends on CCIP availability
- Not audited; intended for educational and experimental use
- Linear interest model may not fit all yield strategies

### Future Developments

- Support for additional chains and multi-hop routing
- Gas optimizations in accrual settlement
- Formal verification of interest and bridging logic
- Frontend UI for deposits and cross-chain bridging
- Audit hardening and production-readiness improvements

### Author

Sivaji (DecentralizedGlasses)
