import "dotenv/config";
import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxViemPlugin from "@nomicfoundation/hardhat-toolbox-viem";

const sepoliaRpcUrl = process.env.SEPOLIA_RPC_URL as string;
const sepoliaPrivateKey = process.env.SEPOLIA_PRIVATE_KEY as `0x${string}`;
const etherscanApiKey = process.env.ETHERSCAN_API_KEY as string;

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },
  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: sepoliaRpcUrl,
      accounts: [sepoliaPrivateKey],
    },
  },
  verify: {
    etherscan: {
      apiKey: etherscanApiKey,
    },
  },
};

export default config;
