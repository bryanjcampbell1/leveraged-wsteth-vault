// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWstEth is IERC20 {
    function stEthPerToken() external view returns (uint256);
    function wrap(uint256 _stETHAmount) external returns (uint256);
    function unwrap(uint256 _wstETHAmount) external returns (uint256);
}