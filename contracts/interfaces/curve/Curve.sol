// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

interface ICurveFi {
    function get_virtual_price() external view returns(uint256);

    function add_liquidity(
        uint256[3] calldata amounts,
        uint256 min_mint_amount
    ) external;

    function add_liquidity(
        uint256[4] calldata amounts,
        uint256 min_mint_amount
    ) external;

    function remove_liquidity_imbalance(uint256[4] calldata amounts, uint256 max_burn_amount) external;

    function remove_liquidity(uint256 _amount, uint256[4] calldata amounts) external;

    function exchange(
        int128 from,
        int128 to,
        uint256 _from_account,
        uint256 _min_to_amount
    ) external;
}