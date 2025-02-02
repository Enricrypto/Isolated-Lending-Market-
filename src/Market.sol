// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract Market {
    // Mapping to track user collateral balances for each collateral token
    mapping(address => mapping(address => uint256))
        public userCollateralBalances;

    // Mapping to track the supported collateral types in the market
    mapping(address => bool) public supportedCollateralTokens;

    // Mapping for borrowable token vaults (ERC4626) for this market
    mapping(address => address) public borrowableVaults; // Borrowable token -> Vault address

    // Mapping to track users' borrowed amounts for each borrowable token
    mapping(address => mapping(address => uint256)) public borrowedAmount; // User -> Token -> Amount

    // Tracks the amount of each loan share lent by each user
    mapping(address => mapping(address => uint256)) public lendShares;
    // User -> Loan Share -> Amount

    // Tracks token equivalent of shares
    mapping(address => mapping(address => uint256)) public lendTokens; // User -> Loan Token -> Amount

    // Mapping for Loan-to-Value (LTV) ratios for borrowable tokens
    mapping(address => uint256) public ltvRatios; // Token -> LTV ratio (percentage out of 100)

    // Array to track all supported collateral tokens
    address[] public collateralTokens;

    // Event for adding borrowable asset vault
    event BorrowableVaultAdded(
        address indexed borrowableToken,
        address indexed vault
    );

    event CollateralTokenAdded(address indexed collateralToken);

    event CollateralDeposited(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );

    event CollateralWithdrawn(
        address indexed user,
        address indexed collateralToken,
        uint256 amount
    );

    event LendTokenRegistered(
        address indexed user,
        address indexed borrowableToken,
        uint256 sharesReceived
    );

    event LendTokenWithdrawn(
        address indexed user,
        address indexed borrowableToken,
        uint256 sharesWithdrawn,
        uint256 tokensReceived
    );

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
        address vault
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

        // Verify that the vault is an actual ERC4626 contract for the given token
        require(
            Vault(vault).asset() == borrowableToken,
            "Vault does not match borrowable token"
        );

        // Add the vault to the borrowableVaults mapping
        borrowableVaults[borrowableToken] = vault;

        // Emit events for logging
        emit BorrowableVaultAdded(borrowableToken, vault);
    }

    // Function to add a collateral type to the market
    function addCollateralToken(
        address collateralToken,
        uint256 ltvRatio
    ) external {
        require(
            collateralToken != address(0),
            "Invalid collateral token address"
        );
        require(
            !supportedCollateralTokens[collateralToken],
            "Collateral token already added"
        );

        // Mark the collateral token as supported
        supportedCollateralTokens[collateralToken] = true;

        // Set the LTV ratio for that specific collateral token (users can define their own LTV for now)
        setLTVRatio(collateralToken, ltvRatio);

        // Add collateral to array to track all supported collateral tokens
        collateralTokens.push(collateralToken);

        emit CollateralTokenAdded(collateralToken);
    }

    function depositCollateral(
        address collateralToken,
        uint256 amount
    ) external {
        // Ensure the collateral token is supported
        require(
            supportedCollateralTokens[collateralToken],
            "Collateral token not supported"
        );

        // Transfer the collateral token from the user to the market contract
        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);

        // Update the user's collateral balance for this token
        userCollateralBalances[msg.sender][collateralToken] += amount;

        // Emit an event for logging
        emit CollateralDeposited(msg.sender, collateralToken, amount);
    }

    function withdrawCollateral(
        address collateralToken,
        uint256 amount
    ) external {
        // Ensure the user has enough collateral to withdraw
        require(
            userCollateralBalances[msg.sender][collateralToken] >= amount,
            "Insufficient collateral balance"
        );

        // Decrease the user's collateral balance
        userCollateralBalances[msg.sender][collateralToken] -= amount;

        // Transfer the collateral token from the market contract to the user
        IERC20(collateralToken).transfer(msg.sender, amount);

        // Emit an event for logging
        emit CollateralWithdrawn(msg.sender, collateralToken, amount);
    }

    // Deposit Lend Tokens into the vault via the market contract
    function depositLendToken(
        address borrowableToken,
        uint256 amount
    ) external {
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Vault not found"
        );

        // Get the vault associated with the borrowable token
        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Transfer tokens from the user to the Market contract
        IERC20(borrowableToken).transferFrom(msg.sender, address(this), amount);

        // Approve the Vault to spend Market's tokens
        IERC20(borrowableToken).approve(address(vault), amount);

        // Deposit tokens into Vault on behalf of the user
        uint256 sharesReceived = vault.deposit(amount, msg.sender);

        // Track the user's shares in the Market contract
        lendShares[msg.sender][borrowableToken] += sharesReceived;
        lendTokens[msg.sender][borrowableToken] += amount;

        emit LendTokenRegistered(msg.sender, borrowableToken, sharesReceived);
    }

    // Function to withdraw a loan token from the market contract
    function withdrawLendToken(
        address borrowableToken,
        uint256 amount
    ) external {
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Vault not found"
        );

        // Get the vault associated with the borrowable token
        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Ensure the user has enough lend tokens to withdraw
        lendTokens[msg.sender][borrowableToken];
        require(
            lendTokens[msg.sender][borrowableToken] >= amount,
            "Insufficient lend balance"
        );

        // Convert token amount to equivalent shares
        uint256 sharesToWithdraw = vault.convertToShares(amount);
        require(sharesToWithdraw > 0, "Invalid share amount");

        // Wikthdraw tokens from vault (burn shares, get tokens back)
        uint256 tokensReceived = vault.withdraw(amount, msg.sender, msg.sender);

        // Update user's share & token balance in Market contract
        lendShares[msg.sender][borrowableToken] -= sharesToWithdraw;
        lendTokens[msg.sender][borrowableToken] -= tokensReceived;

        // Emit event for logging
        emit LendTokenWithdrawn(
            msg.sender,
            borrowableToken,
            sharesToWithdraw,
            tokensReceived
        );
    }

    function borrow(address borrowableToken, uint256 amount) public {
        // Ensure borrowable token is supported
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Borrowable asset not supported"
        );

        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Get the user's collateral value
        uint256 userCollateralValue = getTotalCollateralValue(msg.sender);

        // Calculate the max borrowable amount
        uint256 maxBorrow = userCollateralValue; // This is the borrowing power

        // Ensure the user is not borrowing more than allowed
        require(amount <= maxBorrow, "Borrow amount exceeds LTV limit");

        // Ensure the vault has enough borrowable funds to lend
        uint256 availableFunds = vault.totalAssets(); // Check vault balance
        require(availableFunds >= amount, "Insufficient funds in vault");

        // Update borrowed amount tracking
        borrowedAmount[msg.sender][borrowableToken] += amount;

        // Withdraw from the Vault (this will handle internal accounting correctly)
        vault.withdraw(amount, address(this), address(this));

        // Transfer the borrowed amount to the borrower
        IERC20(borrowableToken).transfer(msg.sender, amount);

        // Emit event for borrowed
        emit Borrowed(msg.sender, borrowableToken, amount);
    }

    // Function to set the LTV ratio for a collateral token
    // Change this for admin control
    function setLTVRatio(address collateralToken, uint256 ratio) internal {
        require(ratio <= 100, "LTV ratio cannot exceed 100");
        require(ratio > 0, "LTV ratio must be greater than 0");

        ltvRatios[collateralToken] = ratio;

        emit LTVRatioSet(collateralToken, ratio);
    }

    // Function to get the LTV ratio for a collateral token
    function getLTVRatio(
        address collateralToken
    ) public view returns (uint256) {
        return ltvRatios[collateralToken];
    }

    // Supporting function to check user/s total collateral
    function getTotalCollateralValue(
        address user
    ) public view returns (uint256 totalBorrowingPower) {
        totalBorrowingPower = 0;

        // Loop through the array of collateral tokens
        for (uint256 i = 0; i < collateralTokens.length; i++) {
            address collateralToken = collateralTokens[i];
            uint256 userCollateralAmount = userCollateralBalances[user][
                collateralToken
            ];
            if (userCollateralAmount > 0) {
                uint256 ltvRatio = getLTVRatio(collateralToken); // LTV per collateral token
                uint256 collateralValue = userCollateralAmount; // Add oracle price fetch LATER
                totalBorrowingPower += (collateralValue * ltvRatio) / 100;
            }
        }
        return totalBorrowingPower;
    }

    // Function that returns the list of collateral tokens
    function getCollateralTokens() public view returns (address[] memory) {
        return collateralTokens;
    }
}
