# Isolated Lending Market
Isolated, Modular and Permissionless 

# Lending Protocol
*Overview* 
This project is a modular and extendable lending protocol built on Solidity. It begins with a single smart contract that handles core operations such as deposits, withdrawals, borrowing, and collateral management. The protocol is designed to evolve into a modular architecture, eventually separating core logic into distinct contracts for better scalability and maintainability.

# Current Functionality
*Core Features*
1. ERC-4626 Vault Implementation:
The contract is built on the ERC-4626 standard, which allows users to deposit and withdraw assets while issuing shares representing their ownership of the vault.
This ensures seamless management of vault shares and assets.

2. Collateral Management:
Users can deposit collateral into the vault, which is tracked individually for each user.
The protocol calculates the maximum borrowing power for users based on their collateral and a predefined Loan-to-Value (LTV) ratio.

3. Borrowing and Debt Management:
Users can borrow assets against their collateral, provided they stay within the allowable LTV ratio.
Borrowing power is dynamically calculated, taking into account the user's collateral balance, LTV ratio, and existing debt.

4. Collateral Utilization:

The contract tracks the percentage of collateral utilized as debt.
This metric helps users monitor their risk levels and avoid overleveraging.

5. Key Functions
- deposit(uint256 amount): Allows users to deposit assets into the vault, increasing their collateral balance and minting vault shares.

- withdraw(uint256 amount): Lets users withdraw assets from their collateral balance, provided they stay within the borrowing constraints set by the LTV ratio.

- getBorrowingPower(address user): Calculates how much more a user can borrow based on their collateral balance, LTV ratio, and current debt.

- getUtilization(address user): Returns the percentage of a user's collateral currently utilized as debt.

*Future Enhancements*
The protocol is designed to eventually separate functionality into modular components:

- Oracle Module: For dynamic price feeds of collateral and borrowed assets.

- Interest Rate Module: To calculate interest rates for borrowers.
- Factory Module: To enable deployment of new lending markets with customizable parameters.
Liquidation Module: To handle collateral liquidation in cases of overleveraging.

<img width="641" alt="Isolated Lending Market Architecture" src="https://github.com/user-attachments/assets/60e0c870-a229-4a5c-82eb-0d8eabf34b9a" />

<img width="661" alt="Screenshot 2025-01-29 at 22 33 36" src="https://github.com/user-attachments/assets/4456df11-1ea0-45e3-bade-23ae6ec0c057" />


