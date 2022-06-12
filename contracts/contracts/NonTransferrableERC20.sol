// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract NonTransferrableERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view virtual returns (uint256);

    function balanceOf(address account) external view virtual returns (uint256);

    function transfer(address to, uint256 amount) external pure returns (bool) {
        return false;
    }

    function allowance(address owner, address spender) external pure returns (uint256) {
        return 0;
    }

    function approve(address spender, uint256 amount) external pure returns (bool) {
        return false;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external pure returns (bool) {
        return false;
    }
}
