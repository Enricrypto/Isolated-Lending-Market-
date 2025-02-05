// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./PriceOracle.sol";

contract InterestRateModel {
    uint256 public baseRate; // // Base interest rate (minimum rate applied to all loans)
    uint256 public slope; // Slope of the rate curve (i.e.: 10% per full utilization = 10e16)
    uint256 public priceFactor; // Weight for price impact
    uint256 public supplyFactor; // Weight for supply-demand impact

    PriceOracle public priceOracle;
    address public owner;

    mapping(address => uint256) public totalSupply;
    mapping(address => uint256) public totalBorrows;
    mapping(address => int256) public lastPrice;

    event InterestRateUpdated(address indexed asset, uint256 rate);

    constructor(
        address _priceOracle,
        uint256 _baseRate,
        uint256 _slope,
        uint256 _priceFactor,
        uint256 _supplyFactor
    ) {
        priceOracle = PriceOracle(_priceOracle);
        baseRate = _baseRate;
        slope = _slope;
        priceFactor = _priceFactor;
        supplyFactor = _supplyFactor;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setBaseRate(uint256 _newBaseRate) external onlyOwner {
        baseRate = _newBaseRate;
    }

    function setSlope(uint256 _newSlope) external onlyOwner {
        slope = _newSlope;
    }

    function getUtilizationRate(address asset) public view returns (uint256) {
        if (totalSupply[asset] == 0) return 0;
        return (totalBorrows[asset] * 1e18) / totalSupply[asset];
    }

    function getPriceVolatility(address asset) public view returns (uint256) {
        int256 latestPrice = priceOracle.getLatestPrice(asset);
        if (lastPrice[asset] == 0) return 0;
        uint256 volatility = abs(int256(lastPrice[asset]) - latestPrice);
        return volatility;
    }

    function getSupplyDemandRatio(address asset) public view returns (uint256) {
        if (totalSupply[asset] == 0) return 0;
        return
            ((totalSupply[asset] - totalBorrows[asset]) * 1e18) /
            totalSupply[asset];
    }

    function getDynamicBorrowRate(address asset) public view returns (uint256) {
        uint256 utilization = getUtilizationRate(asset);
        uint256 priceVolatility = getPriceVolatility(asset);
        uint256 supplyDemandRatio = getSupplyDemandRatio(asset);

        uint256 rate = baseRate +
            ((slope * utilization) / 1e18) +
            ((priceFactor * priceVolatility) / 1e18) +
            ((supplyFactor * supplyDemandRatio) / 1e18);

        return rate;
    }

    function updateLastPrice(address asset) external {
        lastPrice[asset] = int256(priceOracle.getLatestPrice(asset));
    }

    function abs(int256 x) private pure returns (uint256) {
        return x < 0 ? uint256(-x) : uint256(x);
    }
}
