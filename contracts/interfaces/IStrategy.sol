// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStrategy {
    function vault() external view returns (address);
    function manager() external view returns (address);
    function idealDebtToCollateral() external returns (uint256);
    function withdrawAllToVault() external;
    function withdrawToVault(uint256 amount) external;
    function redeem(uint256 shares) external returns(uint256);
    function invest(uint256 amount) external;
    function harvest() external;
    function setDebtToCollateral(uint256 idealDebtToCollateral) external;
    function setManager(address manager) external;
    function previewWithdrawToVault(uint256 amount) external view returns (uint256);
    function previewRedeem(uint256 amount) external view returns (uint256);
}
