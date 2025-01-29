// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Vault is ERC4626 {
    // Events
    event Deposit(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    constructor(
        address _asset,
        string memory _name, // name of the vault share token
        string memory _symbol // symbol of the vault share token
    ) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {}

    /// @notice Deposit ERC-20 tokens into the vault
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256 shares) {
        require(assets > 0, " Deposit amount must be greater than 0");

        // Call the ERC4626 deposit logic
        shares = super.deposit(assets, receiver);

        return shares;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override returns (uint256 shares) {
        // Call the default ERC4626 withdraw logic
        shares = super.withdraw(assets, receiver, owner);

        return shares;
    }

    function withdrawForBorrower(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        // Ensure the vault has enough funds for the withdrawal
        // asset() is a built-in function that point to the asset that the vault holds
        uint256 availableAssets = IERC20(asset()).balanceOf(address(this));
        require(availableAssets >= assets, "Insufficient funds in vault");

        // Transfer the assets to the borrower (without burning shares)
        IERC20(asset()).transfer(receiver, assets);

        // Emit event for withdrawal
        emit Withdraw(msg.sender, assets);

        return assets; // Return the amount withdrawn
    }
}
