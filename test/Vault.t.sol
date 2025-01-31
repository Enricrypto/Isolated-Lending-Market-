// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import "../src/Vault.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract VaultTest is Test {
    Vault public vault;
    address public user;
    address public receiver;
    IERC20 public dai;

    address daiAddress = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address on Arbitrum

    uint256 public initialDeposit = 5000 * 1e18; // 5000 tokens
    uint256 public initialUserBalance = 10000 * 1e18; // 2000 DAI for user

    function setUp() public {
        // Fork the Arbitrum mainnet at the latest block
        vm.createSelectFork(
            "https://arb-mainnet.g.alchemy.com/v2/ADLPIIv6SUjhmaoJYxWLHKDUDaw8RnRj",
            301134183
        );

        // Deploy Vault contract
        vault = new Vault(daiAddress, "Vault Dai", "VDAI");

        // Initialize the DAI instance
        dai = IERC20(daiAddress);

        // Set up accounts
        user = address(0x123);
        receiver = address(0x456);

        // send some Ether to the user
        vm.deal(user, 10 ether);

        // Impersonate a DAI whale to send tokens to the user
        address daiWhale = 0xd85E038593d7A098614721EaE955EC2022B9B91B; // Replace with a valid DAI whale address
        vm.startPrank(daiWhale);
        dai.transfer(user, initialUserBalance); // Transfer 10,000 DAI to user
        vm.stopPrank();

        // Approve the vault contract for the user
        vm.startPrank(user);
        dai.approve(address(vault), type(uint256).max); // Approve max amount
        vm.stopPrank();
    }

    // Test deposit function
    function testDeposit() public {
        uint256 depositAmount = initialDeposit;

        // Log initial user DAI balance
        uint256 initialDaiBalance = dai.balanceOf(user);
        console.log("Initial user DAI balance:", initialDaiBalance);

        // Log initial vault DAI balance
        uint256 initialVaultDaiBalance = dai.balanceOf(address(vault)); // Get the vault's DAI balance
        console.log("Initial vault DAI balance:", initialVaultDaiBalance);

        // Log initial user shares balance
        uint256 initialShares = vault.balanceOf(user);
        console.log("Initial user shares balance:", initialShares);

        // User deposits DAI into the vault
        vm.prank(user);
        uint256 sharesMinted = vault.deposit(depositAmount, user);

        // Log shares minted
        console.log("Shares minted:", sharesMinted);

        // Assert the shares minted match the deposit amount (1:1 ratio)
        assertEq(
            sharesMinted,
            depositAmount,
            "Shares minted should match the deposited amount"
        );

        // Get the user's shares balance after deposit
        uint256 userShares = vault.balanceOf(user);
        console.log("User shares balance after deposit:", userShares);

        // Assert the user's shares balance is updated correctly
        uint256 expectedShares = initialShares + sharesMinted;
        assertEq(
            userShares,
            expectedShares,
            "User shares balance should match the expected value"
        );

        // Log final user DAI balance
        uint256 finalDaiBalance = dai.balanceOf(user);
        console.log("Final user DAI balance:", finalDaiBalance);

        // Assert that the user's DAI balance has decreased by the deposit amount
        uint256 expectedDaiBalance = initialDaiBalance - depositAmount;
        assertEq(
            finalDaiBalance,
            expectedDaiBalance,
            "User DAI balance should decrease by the deposited amount"
        );

        // Log final vault DAI balance
        uint256 finalVaultDaiBalance = dai.balanceOf(address(vault));
        console.log("Final vault DAI balance:", finalVaultDaiBalance);

        // Assert that the vault's DAI balance has increased by the deposit amount
        uint256 expectedVaultDaiBalance = initialVaultDaiBalance +
            depositAmount;
        assertEq(
            finalVaultDaiBalance,
            expectedVaultDaiBalance,
            "Vault DAI balance should increase by the deposited amount"
        );
    }

    function testWithdraw() public {
        uint256 withdrawAmount = 500 * 1e18; // Withdraw 500 tokens
        uint256 depositAmount = initialDeposit;

        // User deposits DAI into the vault
        vm.prank(user);
        vault.deposit(depositAmount, user);

        // Log initial vault token (shares) balance
        uint256 initialShares = vault.balanceOf(user);
        console.log("Initial shares balance:", initialShares);

        // Log initial receiver balance
        uint256 initialReceiverBalance = dai.balanceOf(receiver);
        console.log("Initial receiver balance:", initialReceiverBalance);

        // Log initial vault collateral (total assets)
        uint256 initialVaultBalance = vault.totalAssets();
        console.log("Initial vault balance:", initialVaultBalance);

        // Perform withdrawal
        vm.startPrank(user);
        uint256 sharesBurned = vault.withdraw(withdrawAmount, receiver, user);
        vm.stopPrank();

        // Log final vault token (shares) balance
        uint256 finalShares = vault.balanceOf(user);
        console.log("Final shares balance:", finalShares);

        // Log final receiver balance
        uint256 finalReceiverBalance = dai.balanceOf(receiver);
        console.log("Final receiver balance:", finalReceiverBalance);

        // Log final vault collateral (total assets)
        uint256 finalVaultBalance = vault.totalAssets();
        console.log("Final vault balance:", finalVaultBalance);

        // Assert shares were burned
        uint256 expectedSharesBurned = vault.previewWithdraw(withdrawAmount);
        assertEq(
            sharesBurned,
            expectedSharesBurned,
            "Shares burned should match the expected shares"
        );

        // Assert receiver's balance increased correctly
        assertEq(
            finalReceiverBalance,
            initialReceiverBalance + withdrawAmount,
            "Receiver balance should increase by the withdrawn amount"
        );

        // Assert user's shares balance decreased
        assertEq(
            finalShares,
            initialShares - sharesBurned,
            "User's shares balance should decrease by the burned shares"
        );

        // Assert vault's total assets decreased
        assertEq(
            finalVaultBalance,
            initialVaultBalance - withdrawAmount,
            "Vault's total assets should decrease by the withdrawn amount"
        );
    }
}
