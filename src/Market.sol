// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";
import "./InterestRateModel.sol";
import "./PriceOracle.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract Market {
    InterestRateModel public interestRateModel;
    PriceOracle public priceOracle;

    // Mapping to track user collateral balances for each collateral token
    mapping(address => mapping(address => uint256))
        public userCollateralBalances;

    // Mapping to track the supported collateral types in the market
    mapping(address => bool) public supportedCollateralTokens;

    // Mapping for borrowable token vaults (ERC4626) for this market
    mapping(address => address) public borrowableVaults; // Borrowable token -> Vault address

    // Mapping to track users' borrowed principal amount
    mapping(address => mapping(address => uint256)) public borrowedAmount; // User -> Token -> Amount

    // Mapping to track the last interest rate at the time of borrowing
    mapping(address => mapping(address => uint256)) public borrowRateAtTime; // User -> Token -> Rate

    // Mapping to track the last update time for interest calculation
    mapping(address => mapping(address => uint256)) public borrowTimestamp; // User -> Token -> Timestamp

    // Mapping to track the amount of interest accumulated
    mapping(address => mapping(address => uint256)) public accumulatedInterest; // User -> Token -> Interest

    // Tracks the amount of each loan share lent by each user
    mapping(address => mapping(address => uint256)) public lendShares; // User -> Loan Share -> Amount

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
        uint256 amount
    );

    event Borrowed(
        address indexed borrower,
        address indexed borrowableToken,
        uint256 amount,
        uint256 borrowRate
    );

    // Event for setting LTV ratio for a borrowable token
    event LTVRatioSet(address indexed borrowableToken, uint256 ltvRatio);

    event Repayment(
        address indexed borrower,
        address indexed borrowableToken,
        uint256 totalRepayAmount
    );

    constructor(
        InterestRateModel _interestRateModel,
        PriceOracle _priceOracle
    ) {
        interestRateModel = _interestRateModel;
        priceOracle = _priceOracle;
    }

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

        // Market approves Vault to spend the tokens
        IERC20(borrowableToken).approve(address(vault), amount);

        // Market deposits tokens into Vault on behalf of the user
        uint256 sharesReceived = vault.deposit(amount, address(this));
        require(sharesReceived > 0, "Deposit failed, no shares received");

        // Track the user's shares and tokens in the Market contract
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

        // Ensure the user has enough lend tokens to withdraw (from market)
        lendTokens[msg.sender][borrowableToken];
        require(
            lendTokens[msg.sender][borrowableToken] >= amount,
            "Insufficient lend balance"
        );

        // Withdraw tokens from vault (burn shares, get tokens back)
        vault.withdraw(amount, msg.sender, address(this));

        // Update user's share & token balance in the Market contract
        uint256 sharesToWithdraw = vault.convertToShares(amount); // Convert the assets withdrawn to shares
        lendShares[msg.sender][borrowableToken] -= sharesToWithdraw;
        lendTokens[msg.sender][borrowableToken] -= amount;

        // Emit event for logging
        emit LendTokenWithdrawn(
            msg.sender,
            borrowableToken,
            sharesToWithdraw,
            amount
        );
    }

    function borrow(address borrowableToken, uint256 amount) public {
        // Ensure borrowable token is supported
        require(
            borrowableVaults[borrowableToken] != address(0),
            "Borrowable asset not supported"
        );

        // Get the user's collateral value
        uint256 userCollateralValue = getTotalCollateralValue(msg.sender);

        // Calculate the max borrowable amount (LTV)
        uint256 maxBorrowAmount = userCollateralValue;

        // Ensure the user is not borrowing more than allowed
        require(amount <= maxBorrowAmount, "Borrow amount exceeds LTV limit");

        Vault vault = Vault(borrowableVaults[borrowableToken]);

        // Ensure the vault has enough borrowable funds to lend
        uint256 availableFunds = vault.totalAssets(); // Get the vault's balance in tokens
        require(availableFunds >= amount, "Insufficient funds in vault");

        uint256 marketShares = vault.balanceOf(address(this));
        require(marketShares > 0, "Market contract owns no shares");

        // Get the utilization rate for the borrowable token
        uint256 utilization = interestRateModel.getUtilizationRate(
            borrowableToken
        );

        // Get the dynamic borrow rate based on utilization from InterestRateModel
        uint256 borrowRate = interestRateModel.getDynamicBorrowRate(
            borrowableToken
        );

        // Store the borrow rate and timestamp at the time of borrowing
        borrowRateAtTime[msg.sender][borrowableToken] = borrowRate;
        borrowTimestamp[msg.sender][borrowableToken] = block.timestamp;

        // This would be the interest to be paid on top of the borrow
        uint256 interestAmount = (amount * borrowRate) / 1e18;

        // Withdraw from the Vault (this will handle internal accounting correctly)
        vault.withdraw(amount, msg.sender, address(this));

        // Update borrowed amount tracking
        borrowedAmount[msg.sender][borrowableToken] += amount;

        // Ensure the vault's funds are updated correctly (funds should decrease)
        uint256 updatedVaultFunds = vault.totalAssets();
        require(
            updatedVaultFunds < availableFunds,
            "Funds have not been updated"
        );

        // Emit event for borrowed
        emit Borrowed(msg.sender, borrowableToken, amount, borrowRate);
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
                uint8 collateralDecimals = getTokenDecimals(collateralToken); // Get collateral token decimals

                // Get the price of the collateral token from the PriceOracle
                int256 collateralPrice = priceOracle.getLatestPrice(
                    collateralToken
                );
                require(collateralPrice > 0, "Invalid price from Oracle");

                uint256 collateralValue = userCollateralAmount *
                    uint256(collateralPrice);

                // If the collateral token has less decimals than DAI (18 decimals), adjust it
                if (collateralDecimals < 18) {
                    collateralValue =
                        collateralValue *
                        (10 ** (18 - collateralDecimals)); // Scale it up to match DAI's 18 decimals
                } else if (collateralDecimals > 18) {
                    collateralValue =
                        collateralValue /
                        (10 ** (collateralDecimals - 18)); // Scale it down if more than 18 decimals
                }

                // Add the collateral value to the total borrowing power, considering LTV
                totalBorrowingPower += (collateralValue * ltvRatio) / 100;
            }
        }
        return totalBorrowingPower;
    }

    // Function to calculate the interests accrued by a borrower
    function calculateAccruedInterest(
        address user,
        address borrowableToken
    ) public view returns (uint256) {
        // Get the principal amount borrowed
        uint256 principal = borrowedAmount[user][borrowableToken];

        // Get the borrow rate at the time of borrowing
        uint256 borrowRate = borrowRateAtTime[user][borrowableToken];

        // Get the last time when the interest was updated (when the loan was taken)
        uint256 lastTimestamp = borrowTimestamp[user][borrowableToken];

        // If the loan was taken just now, return 0 interest
        if (lastTimestamp == 0) return 0;

        // Calculate the time elapsed since the last update
        uint256 timeElapsed = block.timestamp - lastTimestamp;

        // Calculate the interest based on the elapsed time and the borrow rate
        // Assume the borrow rate is annual (rate per second)
        uint256 interest = (principal * borrowRate * timeElapsed) /
            (365 days * 1e18);

        return interest;
    }

    function repay(address borrowableToken, uint256 amount) public {
        // Ensure the user has borrowed this token
        require(
            borrowedAmount[msg.sender][borrowableToken] > 0,
            "No debt to repay"
        );

        // Calculate the interest accrued
        uint256 interest = calculateAccruedInterest(
            msg.sender,
            borrowableToken
        );

        // Calculate the total amount to repay (principal + interest)
        uint256 totalRepayAmount = borrowedAmount[msg.sender][borrowableToken] +
            interest;

        // Ensure the user is paying the full amount of debt
        require(
            amount >= totalRepayAmount,
            "Repayment amount is less than total debt"
        );

        // Transfer the repayment amount from the user to the market
        IERC20(borrowableToken).transferFrom(
            msg.sender,
            address(this),
            totalRepayAmount
        );

        // Decrease the user's borrowed amount
        borrowedAmount[msg.sender][borrowableToken] = 0;

        // Optionally, update other debt-related variables (like interest, if you want to compound interest)
        accumulatedInterest[msg.sender][borrowableToken] = 0;

        // Emit a repayment event
        emit Repayment(msg.sender, borrowableToken, totalRepayAmount);
    }

    // ======= HELPER FUNCTIONS ========
    // Function that returns the list of collateral tokens
    function getCollateralTokens() internal returns (address[] memory) {
        return collateralTokens;
    }

    function getTokenDecimals(address token) internal returns (uint8) {
        return IERC20Metadata(token).decimals();
    }
}
