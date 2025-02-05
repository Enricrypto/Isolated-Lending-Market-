// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract interestRateModel {
    // Interest Rate Model Constants
    uint256 public baseRate; // Base rate in percentage (i.e.: 2% = 2e16)
    uint256 public slope; // Slope of the rate curve (i.e.: 10% per full utilization = 10e16)

    constructor(uint256 _baseRate, uint256 _slope) {
        baseRate = _baseRate;
        slope = _slope;
    }

    // Function to get the utilization rate (for example, total borrowed / total liquidity)
    function getUtilizationRate(
        uint256 totalBorrowed,
        uint256 totalLiquidity
    ) public pure returns (uint256) {
        if (totalLiquidity == 0) return 0; // Prevent division by zero
        return (totalBorrowed * 1e18) / totalLiquidity; // Returns utilization as a value between 0 and 1e18
    }

    // Function to get the dynamic interest rate based on utilization
    function getDynamicBorrowRate(
        uint256 totalBorrowed,
        uint256 totalLiquidity
    ) public view returns (uint256) {
        // Get the utilization rate based on borrowed vs total liquidity
        uint256 utilization = getUtilizationRate(totalBorrowed, totalLiquidity);

        // Ensure utilization is within a safe range [0, 1e18]
        require(utilization <= 1e18, "Utilization rate cannot exceed 100%");

        // Calculate the dynmaic borrow rate
        uint256 rate = baseRate + (slope * utilization) / 1e18;
        return rate;
    }

    // Function to calculate interest earned by lenders (same as borrowers)
    function getDynamicLenderrate(
        uint256 totalBorrowed,
        uint256 totalLiquidity
    ) public view returns (uint256) {
        // Lender interest rate could be based on o adifferent slope but it typically mirrors the borrow rate
        return getDynamicBorrowRate(totalBorrowed, totalLiquidity);
    }
}
