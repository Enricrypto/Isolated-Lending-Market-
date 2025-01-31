// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/forge-std/src/Test.sol";
import "lib/forge-std/src/console.sol";
import "../src/Vault.sol";
import "../src/Market.sol";
import "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract MarketTest is Test {
    Market public market;
    Vault public daiVault;
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

        // DAI and USDT addresses
        dai = IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1); // DAI token address
        usdt = IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9); // USDT token address

        // Deploy the Vault contract for a specific token
        daiVault = new Vault(address(dai), "vDai", "vDAI");

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
        usdt.transfer(user, 10000 * 1e6); // Transfer 5000 USDT to user
        vm.stopPrank();

        // Approve the market contract for both DAI and USDT
        vm.startPrank(user);
        dai.approve(address(market), type(uint256).max);
        usdt.approve(address(market), type(uint256).max);
        vm.stopPrank();
    }

    function testAddBorrowableVault() public {
        address borrowableToken = address(0x1234); // Example token address
        address vault = address(0x5678); // Example vault address

        // Add the borrowable vault to the market
        market.addBorrowableVault(borrowableToken, vault);

        // Assert that the borrowableVaults mapping is updated correctly
        assertEq(
            market.borrowableVaults(borrowableToken),
            vault,
            "Borrowable vault is updated correctly"
        );
    }

    // Test Add Collateral Token to market
    function testAddCollateralToken() public {
        address collateralToken = address(usdt); // Example token address
        uint256 ltvRatio = 75; // 75% LTV Ratio

        vm.startPrank(user); // Any user can now add collateral and set LTV
        market.addCollateralToken(collateralToken, ltvRatio);
        vm.stopPrank();

        // Assert that the supportedCollateral mapping is now supported
        assertEq(
            market.supportedCollateralTokens(collateralToken),
            true,
            "Collateral supported by market"
        );

        assertEq(
            market.getLTVRatio(collateralToken),
            ltvRatio,
            "LTV Ratio has been set correctly"
        );
    }

    // Test depositCollateral for DAI
    function testDepositCollateral() public {
        address collateralToken = address(usdt); // USDT as collateral
        uint256 deposit = 5000 * 1e6; // 1000 USDT

        // First, we add USDT as a collateral token
        vm.startPrank(user);
        market.addCollateralToken(collateralToken, 75); // 75% LTV
        vm.stopPrank();

        // Ensure the user has USDT before depositing
        assertGe(usdt.balanceOf(user), deposit, "User should have enough USDT");

        // Deposit collateral into the market
        vm.startPrank(user);
        market.depositCollateral(collateralToken, deposit);
        vm.stopPrank();

        // Ensure the contract received the USDT
        assertEq(
            usdt.balanceOf(address(market)),
            deposit,
            "Market should receive deposited collateral"
        );

        // Ensure the user's collateral balance updated correctly
        assertEq(
            market.userCollateralBalances(user, collateralToken),
            deposit,
            "User's collateral balance should be updated"
        );
    }

    // Test for withdraw Collateral
    function testWithdrawCollateral() public {
        address collateralToken = address(usdt);
        uint256 depositValue = 1000 * 1e6; // 1000 USDT
        uint256 withdrawValue = 500 * 1e6; // Withdraw 500 USDT

        // First, we add USDT as a collateral token
        vm.startPrank(user);
        market.addCollateralToken(collateralToken, 75); // 75% LTV
        vm.stopPrank();

        // Ensure the user has USDT before depositing
        uint256 initialbalance = usdt.balanceOf(user);
        assertGe(initialbalance, depositValue, "User should have enough USDT");

        // Deposit collateral into the market
        vm.startPrank(user);
        market.depositCollateral(collateralToken, depositValue);
        vm.stopPrank();

        // User's collateral balance should be updated
        uint256 balanceAfterDeposit = usdt.balanceOf(user);
        assertEq(
            market.userCollateralBalances(user, collateralToken),
            depositValue,
            "User should have deposited collateral"
        );

        // Withdraw collateral
        vm.startPrank(user);
        market.withdrawCollateral(collateralToken, withdrawValue);
        vm.stopPrank();

        // Ensure the contract sent the USDT back to the user
        assertEq(
            usdt.balanceOf(user),
            balanceAfterDeposit + withdrawValue,
            "User should receive withdrawn USDT"
        );

        // Ensure the user's collateral balance updated correctly
        assertEq(
            market.userCollateralBalances(user, collateralToken),
            depositValue - withdrawValue,
            "User's collateral balance should decrease"
        );
    }

    // Test Deposit Lend Token
    function testDepositLendToken() public {
        uint256 deposit = 5000 * 1e18; // 5000 tokens
        // Add the borrowable vault to the market
        vm.startPrank(user);
        market.addBorrowableVault(address(dai), address(daiVault));
        vm.stopPrank();

        // Assert that the borrowableVaults mapping is updated correctly
        assertEq(
            market.borrowableVaults(address(dai)),
            address(daiVault),
            "Borrowable vault is updated correctly"
        );

        // User starts with 0 balance
        uint256 initialVaultBalance = daiVault.balanceOf(user);
        uint256 initialDaiBalance = dai.balanceOf(user);
        console.log("Initial Balance:", initialVaultBalance);
        console.log("Initial DAI balance:", initialDaiBalance);

        assertEq(dai.allowance(user, address(market)), type(uint256).max);

        // Call the deposit function
        vm.startPrank(user);
        market.depositLendToken(address(dai), deposit); // deposit 5000 tokens
        vm.stopPrank();

        // Verify the vault has received the deposit amount
        uint256 finalBalance = daiVault.balanceOf(user);
        assertEq(
            finalBalance,
            initialDaiBalance + deposit,
            "Balance after deposit mismatch"
        );
    }
}
