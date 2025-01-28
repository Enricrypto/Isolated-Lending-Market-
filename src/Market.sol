// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";

contract Market {
    // Mapping for collateral token vaults (ERC4626) for this market
    mapping(address => address) public collateralVaults; // Collateral token -> Vault address

    // Mapping for borrowable token vaults (ERC4626) for this market
    mapping(address => address) public borrowableVaults; // Borrowable token -> Vault address

    // Mapping for Loan-to-Value (LTV) ratios for borrowable tokens
    mapping(address => uint256) public ltvRatios; // Token -> LTV ratio (percentage out of 100)

    // Mapping to track users' borrowed amounts for each borrowable token
    mapping(address => mapping(address => uint256)) public borrowedAmount; // User -> Token -> Amount

    // Event for depositing collateral
    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );

    // Event for adding a collateral vault
    event CollateralVaultAdded(
        address indexed collateralToken, // The address of the collateral token
        address indexed vault // The address of the vault contract for this token
    );

    constructor() {}

    function addCollateralVault(
        address collateralToken,
        address vault
    ) external {
        require(collateralToken != address(0), "Invalid collateral token");
        require(vault != address(0), "Invalid vault address");
        require(
            collateralVaults[collateralToken] == address(0),
            "Vault already exists for this collateral"
        );

        collateralVaults[collateralToken] = vault;

        emit CollateralVaultAdded(collateralToken, vault);
    }

    function depositCollateral(
        address collateralToken,
        uint256 amount
    ) external returns (uint256 shares) {
        // Ensure the vault exists for this collateral token
        require(
            collateralVaults[collateralToken] != address(0),
            "Vault not found for this collateral"
        );

        // Get the vault for the collateral token
        Vault vault = Vault(collateralVaults[collateralToken]);

        // Deposit the collateral into the vault and mint shares for the user
        shares = vault.deposit(amount, msg.sender);

        // Emit an event for logging
        emit CollateralDeposited(msg.sender, collateralToken, amount);

        return shares;
    }
}
