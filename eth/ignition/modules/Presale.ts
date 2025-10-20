import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import VelirionModule from "./Velirion.js";

export default buildModule("PresaleModule", (m) => {
  const velirionModule = m.useModule(VelirionModule);

  const owner = m.getParameter<string>("owner", "0x8CD0191a4fDa1D1e519633a324317094f6BE5F3f");
  const totalForSale = m.getParameter<bigint>("totalForSale", 1_000_000n * 10n ** 18n);
  const basePrice = m.getParameter<bigint>("basePriceQuotePerToken", 1_000_000n); // e.g., 1 USDC (6 decimals)
  const increment = m.getParameter<bigint>("priceIncrementPerPhaseQuote", 100_000n); // +0.1 USDC
  const perPhase = m.getParameter<bigint>("perPhaseAllocation", 0n);
  const quoteTokens = m.getParameter<string[]>("quoteTokens", ["0x5e9d1b4876e96c7f61e5fbecc23be5be845ac95a"]);
  const ethEnabled = m.getParameter<boolean>("ethEnabled", false);

  const presale = m.contract("Presale", [
    owner,
    velirionModule.velirion,
    quoteTokens,
    owner,
    totalForSale,
    basePrice,
    increment,
    perPhase,
    ethEnabled,
  ]);

  return { presale };
});


