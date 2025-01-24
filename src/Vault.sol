// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract VaultwithMarket is ERC4626 {
    uint256 public constant LTV_RATIO = 50; // 50% LTV Ratio
    uint256 public totalDebt; // Total system debt

    mapping(address => uint256) public collateralBalances; // user colleral balances
    mapping(address => uint256) public debtBalances; // user debt balances

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        IERC20 asset, // the underlying token (e.g., DAI)
        string memory name, // name of the vault share token
        string memory symbol // symbol of the vault share token
    ) ERC4626(asset) ERC20(name, symbol) {
        // Initialization logic (if any)
    }

    /// @notice Deposit collateral into the vault
    /// @param amount The amount of the underlying token to deposit
    function depositCollateral(uint256 amount) external {
        require(amount > 0, " Deposit amount must be greater than 0");
        // Transfer the underlying asset to the vault
        asset.transferFrom(msg.sender, address(this), amount);

        //update collateral balance and total collateral
        collateralBalances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /// @notice Borrow against deposited collateral
    /// @param amount The amount of the underlying token to borrow
    function borrow(uint256 amount) external {
        uint256 maxBorrow = (collateralBalances[msg.sender] * LTV_RATIO) / 100;
        require(
            debtBalances[msg.sender] + amount <= maxBorrow,
            "Exceeds LTV ratio"
        );

        // Update user debt and total system debt
        debtBalances[msg.sender] += amount;
        totalDebt += amount;

        // Transfer borrow funds to the user
        asset.transfer(msg.sender, amount);

        emit Borrow(msg.sender, amount);
    }

    /// @notice Repay borrowed debt
    /// @param amount The amount of the underlying token to repay
    function repay(uint256 amount) external {
        require(amount > 0, "Repayment amount muste be greater than 0");
        require(debtBalances[msg.sender] >= amount, "Repayment exceeds debt");

        // Transfer repyament from the user to the vault
        asset.transferFrom(msg.sender, address(this), amount);

        // Update user debt and total system debt
        debtBalances[msg.sender] -= amount;
        totalDebt -= amount;

        emit Repay(msg.sender, amount);
    }

    /// @notice Withdraw collateral from the vault
    /// @param amount The amount of the underlying token to withdraw
    function withdrawCollateral(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(
            collateralBalances[msg.sender] >= amount,
            "Insufficient Collateral"
        );

        uint256 maxWithdraw = ((collateralBalances[msg.sender] *
            (100 - LTV_RATIO)) / 100);
        require(
            debtBalances[msg.sender] <= maxWithdraw,
            "Cannot withdraw while overleveraged"
        );

        // Update user's collateral balance
        collateralBalances[msg.sender] -= amount;

        // Transfer collateral back to the user
        asset.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /// @notice Get user's available borrowing power
    /// @param user The address of the user
    /// @return The maximum amount the user can borrow
    function getBorrowingPower(address user) public view returns (uint256) {
        return
            (collateralBalances[user] * LTV_RATIO) / 100 - debtBalances[user];
    }

    /// @notice Get user's collateral utilization rate
    /// @param user The address of the user
    /// @return The percentage of collateral utilized
    function getUtilization(address user) public view returns (uint256) {
        if (collateralBalances[user] == 0) return 0;
        return (debtBalances[user] * 100) / collateralBalances[user];
    }
}
