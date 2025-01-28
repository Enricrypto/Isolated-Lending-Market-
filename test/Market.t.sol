// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Vault.sol";
import "../src/Market.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MarketTest is Test {
    Market public market;
    Vault public daiVault;
    Vault public usdtVault;
    IERC20 public dai;
    IERC20 public usdt;

    address public user;

    uint256 public depositAmount = 1000 * 1e18; // 1000 tokens

    function setUp() public {
        // Fork the Arbitrum mainnet at the latest block
        vm.createSelectFork(
            "https://arb-mainnet.g.alchemy.com/v2/ADLPIIv6SUjhmaoJYxWLHKDUDaw8RnRj",
            293933340
        );

        // Deploy the market contract
        market = new Market();
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI token address
        usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // USDT token address

        // Deploy Vault contracts for DAI and USDT
        daiVault = new Vault(address(dai), "DAI Vault", "dDAI");
        usdtVault = new Vault(address(usdt), "USDT Vault", "dUSDT");

        // Add Collateral Vaults for testing
        market.addCollateralVault(address(dai), address(daiVault));

        // Initialize DAI and USDT tokens
        dai = IERC20(dai);
        usdt = IERC20(usdt);

        // Set up a user address
        user = address(0x123);

        // send some Ether to the user
        vm.deal(user, 10 ether);

        // Impersonate a DAI whale to send DAI tokens to the user
        address daiWhale = 0xd85E038593d7A098614721EaE955EC2022B9B91B;
        vm.startPrank(daiWhale);
        dai.transfer(user, 10000 * 1e18); // Transfer 10000 DAI to user
        vm.stopPrank();

        // Impersonate a USDT whale to send USDT tokens to the user
        address usdtWhale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
        vm.startPrank(usdtWhale);
        usdt.transfer(user, 5000 * 1e6); // Transfer 5000 USDT to user
        vm.stopPrank();

        // Approve the market contract for both DAI and USDT
        vm.startPrank(user);
        dai.approve(address(market), type(uint256).max);
        usdt.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    // Test to check if the DAI token is correctly mapped to the vault address
    function testCollateralVaultRegistration() public view {
        // Retrieve the vault address for the DAI token from the market contract
        address registeredVault = market.collateralVaults(address(dai));

        // Assert that the registered vault matches the deployed vault address
        assertEq(
            registeredVault,
            address(daiVault),
            "Vault address not correctly mapped for DAI."
        );
    }

    // Test depositCollateral for DAI
    function testDepositCollateralDAI() public {
        uint256 initialDeposit = 5000 * 1e18;

        uint256 initialUserDaiBalance = dai.balanceOf(user);
        console.log("Initial DAI Balance:", initialUserDaiBalance);
        uint256 initialVaultDaiBalance = daiVault.balanceOf(user);
        console.log("Initial Vault DAI Shares:", initialVaultDaiBalance);

        // User deposits collateral (DAI)
        vm.startPrank(user);
        market.depositCollateral(address(dai), initialDeposit);
        vm.stopPrank();

        // Check if the user’s DAI balance decreased
        uint256 userDaiBalanceAfterDeposit = dai.balanceOf(user);
        uint256 vaultDaiBalanceAfterDeposit = daiVault.balanceOf(user);

        console.log(
            "User DAI Balance After Deposit:",
            userDaiBalanceAfterDeposit
        );

        console.log(
            "Vault DAI Shares After Deposit:",
            vaultDaiBalanceAfterDeposit
        );

        // Verify that DAI balance has decreased by the deposit amount
        assertEq(
            initialUserDaiBalance - userDaiBalanceAfterDeposit,
            depositAmount,
            "User DAI balance should decrease by the deposit amount"
        );

        // Verify that vault shares have increased by the corresponding amount
        assertEq(
            vaultDaiBalanceAfterDeposit - initialVaultDaiBalance,
            depositAmount,
            "Vault shares should increase by the deposit amount"
        );
    }
}
