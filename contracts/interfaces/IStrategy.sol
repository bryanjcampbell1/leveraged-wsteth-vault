// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IStrategy {
    function vault() external view returns (address);
    function manager() external view returns (address);
    function withdrawAllToVault() external;
    function withdrawToVault(uint256 amount) external;
    function invest(uint256 amount) external;
    function harvest() external;
    function setDebtToCollateral(uint256 _idealDebtToCollateral) external;
    function setManager(address _manager) external;
    function previewWithdrawToVault(uint256 amount) external view returns (uint256);
}
