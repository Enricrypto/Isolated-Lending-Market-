# Overview
The Isolated Lending Market Protocol is a modular, extendable, and permissionless lending platform built on Solidity. It provides a flexible framework for decentralized lending, enabling users to deposit collateral, borrow assets, and lend tokens within isolated, individual markets. The protocol is built with scalability in mind, ensuring future flexibility through modular contract design and allowing for easy upgrades and expansion.

# Key Features
1. ERC-4626 Vault Implementation
The protocol uses the ERC-4626 standard for vaults, which enables seamless management of assets and vault shares. Users can deposit and withdraw assets within the vaults while receiving shares that represent their stake in the vault.

2. Collateral Management
Users can deposit collateral into the market for borrowing.
Collateral is tracked on a per-user and per-collateral-token basis.
The protocol calculates the maximum borrowing power based on the collateral value and a predefined Loan-to-Value (LTV) ratio.
The protocol also tracks the collateral utilization to help users monitor their risk levels.

3. Borrowing and Debt Management
Users can borrow assets against their collateral, as long as they remain within the allowable LTV ratio.
Borrowing power is dynamically calculated based on the user's collateral balance and current debt.
The protocol ensures that users can only borrow up to a percentage of their collateral's value, preventing over-leveraging.

4. Lending and Borrowable Vaults
Users can lend assets by depositing them into the borrowable vaults (ERC-4626), where they earn vault shares in return for their deposits.
Borrowable assets are stored in separate vaults, each linked to a specific token.
When users deposit loan tokens into the vault, the contract tracks the amount lent by each user.

5. Modular and Permissionless
The protocol is built to be modular, with the ability to add new collateral types, borrowable tokens, and vaults.
It is designed to support permissionless interaction, where anyone can contribute by adding new collateral types or implementing new borrowable assets.

# Core Contract Functions: 

1. Deposit and Withdraw loan Tokens
deposit(uint256 amount): Allows users to deposit loan tokens into a vault, increasing their balance and minting corresponding vault shares. 
As well, you can deposit loan tokens to accrue yield. 
withdraw(uint256 amount): Allows users to withdraw loan tokens from a vault, reducing their balance and burning corresponding vault shares.

2. Borrowing
borrow(address borrowableToken, uint256 amount): Allows users to borrow a specified amount of a borrowable token, provided they stay within their available borrowing power based on their collateral and LTV ratio.

3. Collateral Management
depositCollateral(address collateralToken, uint256 amount): Allows users to deposit collateral into the market, which is tracked individually for each user and collateral type.
withdrawCollateral(address collateralToken, uint256 amount): Allows users to withdraw collateral from the market, as long as they stay within their borrowing constraints (LTV ratio).

4. LTV Ratio and Borrowing Power
setLTVRatio(address borrowableToken, uint256 ratio): Admin function to set the Loan-to-Value (LTV) ratio for a specific borrowable token.
getLTVRatio(address borrowableToken): Retrieves the LTV ratio for a borrowable token.
getBorrowingPower(address user): Calculates the maximum amount a user can borrow, based on their collateral balance and LTV ratio.

5. Supporting Functions
getTotalCollateralValue(address user): Returns the total collateral value of a user, considering all collateral tokens they have deposited (can later incorporate price oracles).
getCollateralTokens(): Returns the list of collateral tokens supported by the market.

# Future Enhancements
The protocol is designed with modularity in mind, and future enhancements will include the separation of core functionality into distinct modules:

*Oracle Module*: For providing dynamic price feeds of collateral and borrowed assets.

*Interest Rate Module*: For calculating interest rates for borrowers.

*Factory Module*: For enabling the deployment of new lending markets with customizable parameters.

*Liquidation Module*: For handling the liquidation of collateral in cases of over-leveraging or default.

# Smart Contract Architecture
*Vault Contract (ERC-4626)*
The Vault contract is the foundation for managing the deposit and withdrawal of tokens. It adheres to the ERC-4626 standard, which ensures compatibility with any ERC-20 token that can be deposited or withdrawn.

Deposit: When users deposit tokens, they receive vault shares in return, representing their ownership in the vault.
Withdraw: When users withdraw tokens, they must burn an equivalent number of vault shares.

*Market Contract*
The Market contract manages the entire lending and borrowing process. It allows users to:

Deposit collateral and borrow against it.
Lend assets by depositing them into ERC-4626 vaults.
Borrow tokens against their collateral and track their borrowing amounts.
Additionally, the Market contract is responsible for managing the LTV ratios and ensuring users stay within their borrowing limits.

<img width="641" alt="Isolated Lending Market Architecture" src="https://github.com/user-attachments/assets/60e0c870-a229-4a5c-82eb-0d8eabf34b9a" />

<img width="661" alt="Screenshot 2025-01-29 at 22 33 36" src="https://github.com/user-attachments/assets/4456df11-1ea0-45e3-bade-23ae6ec0c057" />


