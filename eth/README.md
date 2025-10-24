# Velirion ERC20 Token Project

This project implements a comprehensive ERC20 token ecosystem with a multi-phase presale mechanism using Hardhat 3 Beta, featuring the native Node.js test runner (`node:test`) and the `viem` library for Ethereum interactions.

## Project Overview

This project includes:

- **Velirion Token (VLR)**: A burnable ERC20 token with minting capabilities
- **Presale Contract**: A sophisticated multi-phase token sale mechanism with dynamic pricing
- **Mock USDC**: A test utility for simulating USDC transactions
- **Comprehensive Testing**: TypeScript integration tests using `node:test` and `viem`
- **Deployment Scripts**: Hardhat Ignition modules for easy deployment
- **Multi-Network Support**: Local simulation, Sepolia testnet, and OP mainnet support

## Smart Contracts

### Velirion Token (`contracts/Velirion.sol`)
- Standard ERC20 implementation with burnable functionality
- Owner-controlled minting capabilities
- Initial supply minted to deployer
- Built on OpenZeppelin contracts for security

### Presale Contract (`contracts/Presale.sol`)
- **Multi-Phase Sales**: 10 phases with increasing prices
- **Flexible Payment**: Supports both ETH and ERC20 quote tokens (e.g., USDC)
- **Dynamic Pricing**: Base price with configurable increments per phase
- **Time Management**: 90-day initial sale period with optional 30-day extension
- **Security Features**: ReentrancyGuard, SafeERC20, and comprehensive access controls
- **Fund Management**: Automatic forwarding of payments to designated recipient

### Mock USDC (`contracts/mocks/MockUSDC.sol`)
- 6-decimal precision test token
- Owner-controlled minting for testing purposes

## Features

### Presale Mechanism
- **10 Phases**: Each phase has a fixed allocation and increasing price
- **Flexible Payment**: Buy with ETH or any approved ERC20 token
- **Automatic Phase Progression**: Moves to next phase when current allocation is sold
- **Price Calculation**: `basePrice + (increment × phaseIndex)`
- **Dust Refunds**: Automatic refund of excess payment amounts

### Security Features
- **ReentrancyGuard**: Prevents reentrancy attacks during purchases
- **SafeERC20**: Safe token transfers with proper error handling
- **Access Control**: Owner-only functions for critical operations
- **Input Validation**: Comprehensive parameter validation and error handling

## Usage

### Prerequisites

1. **Node.js**: Version 18 or higher
2. **Environment Variables**: Create a `.env` file with:
   ```
   SEPOLIA_RPC_URL=your_sepolia_rpc_url
   SEPOLIA_PRIVATE_KEY=your_private_key
   ETHERSCAN_API_KEY=your_etherscan_api_key
   ```

### Installation

```shell
npm install
```

### Running Tests

To run all the tests in the project:

```shell
npx hardhat test
```

Run specific test suites:

```shell
# Run only Solidity tests
npx hardhat test solidity

# Run only TypeScript tests
npx hardhat test nodejs
```

### Deployment

#### Deploy Velirion Token

Deploy to local network:
```shell
npx hardhat ignition deploy ignition/modules/Velirion.ts
```

Deploy to Sepolia:
```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Velirion.ts
```

#### Deploy Presale Contract

Deploy to local network:
```shell
npx hardhat ignition deploy ignition/modules/Presale.ts
```

Deploy to Sepolia:
```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Presale.ts
```

### Network Configuration

The project supports multiple networks:

- **hardhatMainnet**: Local L1 simulation
- **hardhatOp**: Local OP mainnet simulation  
- **sepolia**: Sepolia testnet

### Testing OP Mainnet Simulation

Test OP mainnet functionality locally:

```shell
npx hardhat run scripts/send-op-tx.ts --network hardhatOp
```

## Contract Parameters

### Velirion Token
- **Name**: "Velirion"
- **Symbol**: "VLR" 
- **Decimals**: 18
- **Initial Supply**: 1,000,000 VLR (configurable)

### Presale Contract
- **Total for Sale**: 1,000,000 VLR (configurable)
- **Phases**: 10 phases with equal allocation
- **Base Price**: 1,000,000 (in quote token smallest units)
- **Price Increment**: 100,000 per phase
- **Sale Duration**: 90 days (extendable by 30 days)
- **Quote Tokens**: Configurable ERC20 tokens
- **ETH Support**: Optional (disabled by default)

## Development

### Project Structure
```
├── contracts/           # Solidity contracts
│   ├── Velirion.sol    # Main token contract
│   ├── Presale.sol     # Presale mechanism
│   └── mocks/          # Test utilities
├── test/               # Test files
├── ignition/          # Deployment modules
├── scripts/           # Utility scripts
└── hardhat.config.ts  # Hardhat configuration
```

### Key Dependencies
- **Hardhat 3 Beta**: Development framework
- **Viem**: Ethereum interaction library
- **OpenZeppelin**: Secure contract implementations
- **TypeScript**: Type-safe development
- **Node:test**: Native test runner
