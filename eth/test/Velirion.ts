import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { network } from "hardhat";

describe("Velirion", async function () {
  const { viem } = await network.connect();

  it("mints initial supply to deployer and supports burn", async function () {
    const decimals = 18n;
    const initialSupply = 1_000_000n * 10n ** decimals;

    const velirion = await viem.deployContract("Velirion", ["Velirion", "VLR", initialSupply]);

    const [owner, other] = await viem.getWalletClients();

    // owner balance equals initial supply
    const ownerBalance = await velirion.read.balanceOf([owner.account.address]);
    assert.equal(ownerBalance, initialSupply);

    // burn some tokens
    await velirion.write.burn([1000n * 10n ** decimals]);
    const ownerBalanceAfterBurn = await velirion.read.balanceOf([owner.account.address]);
    assert.equal(ownerBalanceAfterBurn, initialSupply - 1000n * 10n ** decimals);
  });

  it("only owner can mint", async function () {
    const decimals = 18n;
    const initialSupply = 0n;

    const velirion = await viem.deployContract("Velirion", ["Velirion", "VLR", initialSupply]);

    const [owner, other] = await viem.getWalletClients();

    // non-owner cannot mint (expect custom Ownable error)
    await viem.assertions.revertWithCustomError(
      velirion.write.mint([other.account.address, 1n * 10n ** decimals], { account: other.account }),
      velirion,
      "OwnableUnauthorizedAccount",
    );

    // owner can mint
    await velirion.write.mint([other.account.address, 1n * 10n ** decimals]);

    const otherBalance = await velirion.read.balanceOf([other.account.address]);
    assert.equal(otherBalance, 1n * 10n ** decimals);
  });
});
