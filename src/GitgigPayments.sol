// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GitGig Payments Contract
 * @notice Handles bounty deposits and payouts with a 5% platform fee.
 */
contract GitGigPayments is Ownable {
    IERC20 public immutable USDC;

    // issueId → bounty amount
    mapping(uint256 => uint256) public bounties;

    // Flat 5% fee
    uint256 public constant FEE_BPS = 500;  // 500 = 5%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    event Deposited(uint256 indexed issueId, uint256 amount, address indexed funder);
    event PaidOut(
        uint256 indexed issueId,
        uint256 totalAmount,
        uint256 devAmount,
        uint256 feeAmount,
        address indexed developer
    );

    constructor(address _usdc) Ownable(msg.sender) {
        require(_usdc != address(0), "Invalid USDC address");
        USDC = IERC20(_usdc);
    }

    /**
     * @notice Deposit USDC to fund a GitHub issue's bounty.
     */
    function deposit(uint256 issueId, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");

        // Pull USDC from sender
        require(
            USDC.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        bounties[issueId] += amount;

        emit Deposited(issueId, amount, msg.sender);
    }

    /**
     * @notice GitGig backend (Oracle) triggers this after PR merge.
     * @dev Only owner can call. Sends 95% to developer, 5% fee to owner.
     */
    function payout(uint256 issueId, address developer) external onlyOwner {
        uint256 amount = bounties[issueId];
        require(amount > 0, "No bounty");
        require(developer != address(0), "Invalid developer wallet");

        // Reset bounty
        bounties[issueId] = 0;

        // Calculate fee + dev payout
        uint256 fee = (amount * FEE_BPS) / BPS_DENOMINATOR;
        uint256 devAmount = amount - fee;

        // Transfers
        require(USDC.transfer(developer, devAmount), "Dev payout failed");
        require(USDC.transfer(owner(), fee), "Fee transfer failed");

        emit PaidOut(issueId, amount, devAmount, fee, developer);
    }
}
