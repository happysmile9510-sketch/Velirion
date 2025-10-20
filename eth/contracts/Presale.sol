// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Presale is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  error SaleNotActive();
  error ZeroAddress();
  error InvalidConfig();
  error NothingToWithdraw();
  error AlreadyExtended();

  struct Phase {
    uint256 priceWeiPerToken; // wei per 1 token unit (1e18)
    uint256 allocation;       // tokens allocated for this phase (in 1e18 units)
    uint256 sold;             // tokens sold in this phase (in 1e18 units)
  }

  IERC20 public immutable token;       // token being sold (18 decimals expected)
  mapping(address => bool) public acceptedQuoteTokens; // dynamic set of accepted ERC20 quote tokens
  address payable public immutable fundsRecipient;

  uint256 public immutable saleStart;
  uint256 public immutable saleEndInitial; // start + 90 days
  uint256 public saleEnd;                  // starts as initial, may extend once by +30 days
  bool public extended;

  uint256 public immutable totalForSale;

  uint256 public constant NUM_PHASES = 10;
  Phase[NUM_PHASES] private phases;

  bool public ethEnabled; // off by default, can be enabled later by owner

  event PurchasedETH(address indexed buyer, uint256 ethSpent, uint256 tokensBought);
  event PurchasedQuote(address indexed buyer, address indexed quote, uint256 quoteSpent, uint256 tokensBought);
  event Extended(uint256 newSaleEnd);
  event WithdrawnETH(uint256 amount);
  event WithdrawnUnsold(address indexed to, uint256 amount);

  constructor(
    address owner_,
    address token_,
    address[] memory initialQuoteTokens_,
    address payable fundsRecipient_,
    uint256 totalForSale_,
    uint256 basePriceQuotePerToken_,
    uint256 priceIncrementPerPhaseQuote_,
    uint256 perPhaseAllocation_, // if 0, defaults to totalForSale_/10
    bool ethEnabled_
  ) Ownable(owner_) {
    if (token_ == address(0) || fundsRecipient_ == address(0)) revert ZeroAddress();
    if (totalForSale_ == 0 || basePriceQuotePerToken_ == 0) revert InvalidConfig();

    token = IERC20(token_);
    fundsRecipient = fundsRecipient_;

    saleStart = block.timestamp;
    saleEndInitial = saleStart + 90 days;
    saleEnd = saleEndInitial;

    totalForSale = totalForSale_;

    uint256 perPhase = perPhaseAllocation_ == 0 ? totalForSale_ / NUM_PHASES : perPhaseAllocation_;
    // Ensure total phase allocation is at least totalForSale_ (last phase will effectively cap on available tokens)
    for (uint256 i = 0; i < NUM_PHASES; i++) {
      phases[i] = Phase({
        priceWeiPerToken: basePriceQuotePerToken_ + (priceIncrementPerPhaseQuote_ * i),
        allocation: perPhase,
        sold: 0
      });
    }

    ethEnabled = ethEnabled_;

    // set initial accepted quote tokens
    for (uint256 j = 0; j < initialQuoteTokens_.length; j++) {
      address qt = initialQuoteTokens_[j];
      if (qt == address(0)) revert ZeroAddress();
      acceptedQuoteTokens[qt] = true;
    }
  }

  // ======== Views ========

  function isActive() public view returns (bool) {
    return block.timestamp >= saleStart && block.timestamp <= saleEnd && totalSold() < totalForSale;
  }

  function totalSold() public view returns (uint256 sold) {
    for (uint256 i = 0; i < NUM_PHASES; i++) {
      sold += phases[i].sold;
    }
  }

  function currentPhaseIndex() public view returns (uint256 index) {
    for (uint256 i = 0; i < NUM_PHASES; i++) {
      if (phases[i].sold < phases[i].allocation) {
        return i;
      }
    }
    return NUM_PHASES - 1; // all full; sales should be capped separately by totalForSale
  }

  function getPhase(uint256 index) external view returns (Phase memory) {
    require(index < NUM_PHASES, "bad phase");
    return phases[index];
  }

  // ======== Admin ========

  function extendOnce() external onlyOwner {
    if (extended) revert AlreadyExtended();
    extended = true;
    saleEnd += 30 days;
    emit Extended(saleEnd);
  }

  function setEthEnabled(bool enabled) external onlyOwner {
    ethEnabled = enabled;
  }

  function addQuoteToken(address tokenAddr) external onlyOwner {
    if (tokenAddr == address(0)) revert ZeroAddress();
    acceptedQuoteTokens[tokenAddr] = true;
  }

  function removeQuoteToken(address tokenAddr) external onlyOwner {
    acceptedQuoteTokens[tokenAddr] = false;
  }

  function withdrawETH(uint256 amount) external onlyOwner {
    if (amount == 0) revert NothingToWithdraw();
    (bool ok, ) = fundsRecipient.call{value: amount}("");
    require(ok, "withdraw failed");
    emit WithdrawnETH(amount);
  }

  function withdrawUnsold(address to) external onlyOwner {
    if (block.timestamp <= saleEnd) revert SaleNotActive(); // only after sale end
    uint256 bal = token.balanceOf(address(this));
    if (bal == 0) revert NothingToWithdraw();
    token.safeTransfer(to, bal);
    emit WithdrawnUnsold(to, bal);
  }

  function depositTokens(uint256 amount) external onlyOwner {
    // owner must approve before calling if using transferFrom pattern; we choose simple transfer to contract
    token.safeTransferFrom(_msgSender(), address(this), amount);
  }

  // ======== Purchasing ========

  // ERC20 purchase path (e.g., USDC). Caller specifies a maximum quote amount to spend.
  function buyWithQuote(address quoteTokenAddr, uint256 maxQuoteAmount) external nonReentrant {
    if (!isActive()) revert SaleNotActive();
    if (maxQuoteAmount == 0) revert InvalidConfig();
    if (!acceptedQuoteTokens[quoteTokenAddr]) revert InvalidConfig();

    uint256 remainingQuote = maxQuoteAmount;
    uint256 totalTokensBought;
    uint256 totalQuoteCost;
    uint256[NUM_PHASES] memory planned; // tokens per phase to finalize after pulling funds

    for (uint256 i = currentPhaseIndex(); i < NUM_PHASES && remainingQuote > 0; i++) {
      Phase storage p = phases[i];
      if (p.sold >= p.allocation) {
        continue;
      }

      uint256 phaseRemaining = p.allocation - p.sold;
      uint256 tokensAffordable = remainingQuote * 1e18 / p.priceWeiPerToken;
      if (tokensAffordable == 0) break;

      uint256 tokensToBuy = tokensAffordable < phaseRemaining ? tokensAffordable : phaseRemaining;

      // Cap by totalForSale
      uint256 soldBefore = totalSold();
      if (soldBefore + tokensToBuy > totalForSale) {
        tokensToBuy = totalForSale - soldBefore;
      }

      if (tokensToBuy == 0) break;

      uint256 cost = tokensToBuy * p.priceWeiPerToken / 1e18;

      planned[i] = tokensToBuy;
      totalTokensBought += tokensToBuy;
      totalQuoteCost += cost;
      remainingQuote -= cost;

      if (totalSold() + totalTokensBought >= totalForSale) {
        break;
      }
    }

    require(totalTokensBought > 0, "insufficient funds");

    // Pull exact required quote from buyer directly to recipient
    IERC20(quoteTokenAddr).safeTransferFrom(msg.sender, fundsRecipient, totalQuoteCost);

    // Finalize sales state and deliver tokens
    for (uint256 i = 0; i < NUM_PHASES; i++) {
      uint256 t = planned[i];
      if (t > 0) {
        phases[i].sold += t;
      }
    }

    token.safeTransfer(msg.sender, totalTokensBought);

    emit PurchasedQuote(msg.sender, quoteTokenAddr, totalQuoteCost, totalTokensBought);
  }

  // ETH purchase path (disabled by default)
  receive() external payable {
    require(ethEnabled, "ETH disabled");
    buyWithETH();
  }

  function buyWithETH() public payable nonReentrant {
    if (!ethEnabled) revert InvalidConfig();
    if (!isActive()) revert SaleNotActive();
    if (msg.value == 0) revert InvalidConfig();

    uint256 remainingValue = msg.value;
    uint256 totalTokensBought;

    for (uint256 i = currentPhaseIndex(); i < NUM_PHASES && remainingValue > 0; i++) {
      Phase storage p = phases[i];
      if (p.sold >= p.allocation) continue;

      uint256 phaseRemaining = p.allocation - p.sold;
      uint256 tokensAffordable = remainingValue * 1e18 / p.priceWeiPerToken;
      if (tokensAffordable == 0) break;

      uint256 tokensToBuy = tokensAffordable < phaseRemaining ? tokensAffordable : phaseRemaining;

      uint256 soldBefore = totalSold();
      if (soldBefore + tokensToBuy > totalForSale) {
        tokensToBuy = totalForSale - soldBefore;
      }

      if (tokensToBuy == 0) break;

      uint256 cost = tokensToBuy * p.priceWeiPerToken / 1e18;

      p.sold += tokensToBuy;
      totalTokensBought += tokensToBuy;
      remainingValue -= cost;

      if (totalSold() >= totalForSale) break;
    }

    require(totalTokensBought > 0, "insufficient ETH");

    // deliver tokens
    token.safeTransfer(msg.sender, totalTokensBought);

    // forward ETH minus refund to fundsRecipient
    uint256 spent = msg.value - remainingValue;
    if (spent > 0) {
      (bool ok1, ) = fundsRecipient.call{value: spent}("");
      require(ok1, "forward failed");
    }

    if (remainingValue > 0) {
      (bool ok2, ) = msg.sender.call{value: remainingValue}("");
      require(ok2, "refund failed");
    }

    emit PurchasedETH(msg.sender, spent, totalTokensBought);
  }
}


