// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor() ERC20("yearn.finance test token", "YFT") {
        _mint(msg.sender, 30000*10**18);
    }
}