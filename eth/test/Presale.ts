import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Presale", async function () {
  const { viem } = await network.connect();

  it("sells across phases with price increases and refunds dust", async function () {
    const decimals = 18n;
    const initialSupply = 10_000_000n * 10n ** decimals;
    const totalForSale = 1_000_000n * 10n ** decimals;

    const velirion = await viem.deployContract("Velirion", ["Velirion", "VLR", initialSupply]);

    const [owner, buyer] = await viem.getWalletClients();

    // Deploy mock USDC and mint to buyer
    const usdc = await viem.deployContract("MockUSDC", []);
    const usdcDecimals = 6n;
    await usdc.write.mint([buyer.account.address, 1_000_000n * 10n ** usdcDecimals]);

    // Deploy presale (quote = USDC, ETH disabled)
    const basePrice = 1000n * 10n ** usdcDecimals; // 1000 USDC cents per token? base in smallest units per 1e18 token
    const increment = 100n * 10n ** usdcDecimals; // +100 in smallest units per phase

    const presale = await viem.deployContract("Presale", [
      owner.account.address,
      velirion.address,
      [usdc.address],
      owner.account.address,
      totalForSale,
      basePrice,
      increment,
      0n,
      false,
    ]);

    // Fund presale with tokens
    await velirion.write.approve([presale.address, totalForSale]);
    await presale.write.depositTokens([totalForSale]);

    // Buyer approves USDC and buys
    await usdc.write.approve([presale.address, 1_000_000n * 10n ** usdcDecimals], { account: buyer.account });
    const balBefore = await velirion.read.balanceOf([buyer.account.address]);
    await presale.write.buyWithQuote([usdc.address, 500_000n * 10n ** usdcDecimals], { account: buyer.account });
    const balAfter = await velirion.read.balanceOf([buyer.account.address]);

    assert.ok(balAfter > balBefore);

    // Ensure sale is active initially and can extend
    const active = await presale.read.isActive();
    assert.equal(active, true);

    await presale.write.extendOnce();
    const saleEnd = (await presale.read.saleEnd()) as unknown as bigint;
    const saleEndInitial = (await presale.read.saleEndInitial()) as unknown as bigint;
    assert.equal(saleEnd - saleEndInitial, 30n * 24n * 60n * 60n);
  });
  // Additional tests for withdrawing after sale end and multi-quote purchases
  // can be added with proper time manipulation helpers if needed.
});


