// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

contract MyVault is ERC4626 {
    constructor(
        IERC20 asset,
        string memory name,
        string memory symbol
    ) ERC4626(asset) ERC20(name, symbol) {
        // Initialization logic (if any)
    }
}
