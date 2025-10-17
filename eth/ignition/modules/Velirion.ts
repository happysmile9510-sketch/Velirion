import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("VelirionModule", (m) => {
  const name = m.getParameter("name", "Velirion");
  const symbol = m.getParameter("symbol", "VLR");
  const initialSupply = m.getParameter<bigint>("initialSupply", 1_000_000n * 10n ** 18n);

  const velirion = m.contract("Velirion", [name, symbol, initialSupply]);

  return { velirion };
});
