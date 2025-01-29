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

    // Storage variable to track all collateral tokens
    address[] public collaterals;

    // Event for adding borrowable asset vault
    event BorrowableVaultAdded(
        address indexed borrowableToken,
        address indexed vault
    );

    // Event for adding a collateral vault
    event CollateralVaultAdded(
        address indexed collateralToken,
        address indexed vault
    );

    // Event for depositing collateral
    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );

    // Event for withdrawing collateral
    event CollateralWithdrawn(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );

    // Event for depositing collateral
    event BorrowableDeposited(
        address indexed user,
        address indexed borrowableToken,
        uint256 amount
    );

    // Event for withdrawing collateral
    event BorrowableWithdrawn(
        address indexed user,
        address indexed borrowableToken,
        uint256 amount
    );

    // Event for borrowed
    event Borrowed(
        address indexed borrower,
        address indexed borrowableToken,
        uint256 amount
    );

    // Event for setting LTV ratio for a borrowable token
    event LTVRatioSet(address indexed borrowableToken, uint256 ltvRatio);

    constructor() {}

    // Function to add a borrowable vault to the market
    function addBorrowableVault(
        address borrowableToken,
        address vault,
        uint256 ltvRatio
    ) external {
        require(
            borrowableToken != address(0),
            "Invalid borrowable token address"
        );
        require(vault != address(0), "Invalid vault address");
        require(
            borrowableVaults[borrowableToken] == address(0),
            "Vault already exists for this borrowable asset"
        );
        require(ltvRatio <= 100, "LTV ratio cannot exceed 100");
        require(ltvRatio > 0, "LTV ratio must be greater than 0");

        // Set the LTV ratio before adding the vault
        setLTVRatio(borrowableToken, ltvRatio);

        // Add the vault to the borrowableVaults mapping
        borrowableVaults[borrowableToken] = vault;

        // Emit events for logging
        emit BorrowableVaultAdded(borrowableToken, vault);
        emit LTVRatioSet(borrowableToken, ltvRatio);
    }

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

        // Add the vault to the collateralVaults mapping
        collateralVaults[collateralToken] = vault;

        // Track the collateral token
        collaterals.push(collateralToken);

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

    function withdrawCollateral(
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

        // Withdraw the collateral from the vault and burn shares of the user
        shares = vault.withdraw(amount, msg.sender, msg.sender);

        // Emit an event for logging
        emit CollateralWithdrawn(msg.sender, collateralToken, amount);

        return shares;
    }

    function depositBorrowable(
        address borrowableToken,
        uint256 amount
    ) external returns (uint256 shares) {
        // Ensure the vault exists for this borrowable token
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Vault not found for this borrowable"
        );

        // Get the vault for the borrowable token
        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Deposit the borrowable into the vault and mint shares for the user
        shares = vault.deposit(amount, msg.sender);

        // Emit an event for logging
        emit BorrowableDeposited(msg.sender, borrowableToken, amount);

        return shares;
    }

    function withdrawBorrowable(
        address borrowableToken,
        uint256 amount
    ) external returns (uint256 shares) {
        // Ensure the vault exists for this borrowable token
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Vault not found for this borrowable"
        );

        // Get the vault for the borrowable token
        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Withdraw the borrowable from the vault and burn shares of the user
        shares = vault.withdraw(amount, msg.sender, msg.sender);

        // Emit an event for logging
        emit CollateralWithdrawn(msg.sender, borrowableToken, amount);

        return shares;
    }

    function borrow(address borrowableToken, uint256 amount) external {
        // Ensure borrowable token is supported
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Borrowable asset not supported"
        );

        // Get the borrowable token vault
        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Get the user's collateral value
        uint256 userCollateralValue = getTotalCollateralValue(msg.sender);

        // Get the LTV ratio for this borrowable token
        uint256 ltvRatio = getLTVRatio(borrowableToken);

        // Calculate the max borrowable amount
        uint256 maxBorrow = (userCollateralValue * ltvRatio) / 100;

        // Ensure the user is not borrowing more than allowed
        require(amount <= maxBorrow, "Borrow amount exceeds LTV limit");

        // Update borrowed amount tracking
        borrowedAmount[msg.sender][borrowableToken] += amount;

        // Ensure the vault has enough borrowable funds to lend
        uint256 availableFunds = vault.totalAssets(); // Check vault balance
        require(availableFunds >= amount, "Insufficient funds in vault");

        // Directly transfer the borrowable token to the user without burning shares
        vault.withdrawForBorrower(amount, msg.sender);

        // Emit event for borrowed
        emit Borrowed(msg.sender, borrowableToken, amount);
    }

    // Function to set the LTV ratio for a borrowable token
    // We will keep this simple for now as we are not using an oracle yet
    function setLTVRatio(address borrowableToken, uint256 ratio) internal {
        ltvRatios[borrowableToken] = ratio;

        emit LTVRatioSet(borrowableToken, ratio);
    }

    // Function to get the LTV ratio for a borrowable token
    function getLTVRatio(
        address borrowableToken
    ) public view returns (uint256) {
        return ltvRatios[borrowableToken];
    }

    // Supporting function to check user/s total collateral
    function getTotalCollateralValue(
        address user
    ) public view returns (uint256 totalValue) {
        address[] memory collateralTokens = getCollateralTokens(); // Array of tokens in the market

        for (uint256 i = 0; i < collateralTokens.length; i++) {
            Vault vault = Vault(collateralVaults[collateralTokens[i]]);
            uint256 userShares = vault.balanceOf(user);
            uint256 assetValue = vault.convertToAssets(userShares); // Convert shares to token amount
            totalValue += assetValue;
        }
    }

    // Function that returns the list of collateral tokens
    function getCollateralTokens() public view returns (address[] memory) {
        return collaterals;
    }
}
