// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Velirion is ERC20, ERC20Burnable, Ownable {
  constructor(
    string memory tokenName,
    string memory tokenSymbol,
    uint256 initialSupply
  ) ERC20(tokenName, tokenSymbol) Ownable(msg.sender) {
    _mint(msg.sender, initialSupply);
  }

  function mint(address to, uint256 amount) external onlyOwner {
    _mint(to, amount);
  }
}
