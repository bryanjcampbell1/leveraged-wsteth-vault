// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";

/**
 * @title AaveStrategy
 * @dev A smart contract implementing a leveraged wstEth stategy with Aave.
 */
contract AaveStrategy is IStrategy, Ownable {

    // Address of the Aave lending pool
    address public constant POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // Address of the wstETH token
    address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    // Address of the Aave interest-bearing token for wstETH
    address public constant A_TOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    // Address of the vault using this strategy
    address public vault;

    // Address of the manager controlling this strategy
    address public manager;

    // Target ideal debt to collateral ratio, expressed in basis points (0-1000)
    uint256 public idealDebtToCollateral;

    // Modifier restricting functions to be callable only by the vault
    modifier onlyVault() {
        require(vault == msg.sender, "Can only be called by the vault");
        _;
    }

    // Modifier restricting functions to be callable only by the vault or strategy itself
    modifier onlyVaultOrStrategy() {
        require(vault == msg.sender || address(this) == msg.sender, "Can only be called by the vault or strategy");
        _;
    }

    // Modifier restricting functions to be callable only by the manager
    modifier onlyManager() {
        require(manager == msg.sender, "Can only be called by the manager");
        _;
    }

    // Modifier restricting functions to be callable only by the vault or manager
    modifier onlyVaultOrManager() {
        require(vault == msg.sender || manager == msg.sender, "Can only be called by the vault or manager");
        _;
    }

    /**
     * @dev Constructor function to initialize the AaveStrategy.
     * @param _vault Address of the vault.
     * @param _manager Address of the manager.
     * @param _idealDebtToCollateral Target ideal debt to collateral ratio.
     */
    constructor(address _vault, address _manager, uint256 _idealDebtToCollateral) Ownable(msg.sender){
        vault = _vault;
        manager = _manager;
        idealDebtToCollateral = _idealDebtToCollateral;
        IERC20(WSTETH).approve(POOL, 2**256 - 1);
        IERC20(A_TOKEN).approve(POOL, 2**256 - 1);
    }

    // ACCESS CONTROLLED PUBLIC FUNCTIONS

    /**
     * @dev Withdraws all assets from the strategy to the vault. Can be called by the manager or the vault.
     *      Transfers the withdrawn WSTETH to the vault. Useful for preparing vault for a change in strategy.
     */
    function withdrawAllToVault() public onlyVaultOrManager {
        _withdrawAllToStrategy();

        // Transfer the remaining WSTETH balance to the vault
        IERC20(WSTETH).transfer(
            vault,
            IERC20(WSTETH).balanceOf(address(this))
        );
    }

    /**
     * @dev Redeems a specified amount of shares, withdrawing assets from the strategy to the vault.
     *      Can only be called by the vault. Returns the amount of WSTETH redeemed.
     * @param _shares The number of shares to redeem.
     * @return redeemAmount The amount of WSTETH redeemed.
     */
    function redeem(uint256 _shares) public onlyVault returns(uint256) {
        // Withdraw all assets to the strategy
        _withdrawAllToStrategy();

        uint256 totalWstEth = IERC20(WSTETH).balanceOf(address(this));
        uint256 totalVaultShares = IERC20(vault).totalSupply();

        // Calculate the amount of WSTETH to redeem based on the number of shares
        uint256 redeemAmount = (_shares * totalWstEth) / totalVaultShares;

        // Transfer the redeemed WSTETH to the vault
        IERC20(WSTETH).transfer(
            vault,
            redeemAmount
        );

        // Invest any remaining WSTETH back into the strategy
        uint256 remaining = IERC20(WSTETH).balanceOf(address(this));
        if (remaining > 0) {
            _invest(remaining, false);
        }

        return redeemAmount;
    }

    /**
     * @dev Withdraws a specified amount of assets from the strategy to the vault.
     *      Can only be called by the vault. Requires that the strategy has enough assets.
     * @param _assets The amount of assets to withdraw.
     */
    function withdrawToVault(uint256 _assets) public onlyVault {
        // Withdraw all assets to the strategy
        _withdrawAllToStrategy();

        uint256 totalWstEth = IERC20(WSTETH).balanceOf(address(this));
        require(totalWstEth > _assets, "Not enough tokens in strategy");

        // Transfer the specified amount of assets to the vault
        IERC20(WSTETH).transfer(
            vault,
            _assets
        );

        // Invest any remaining WSTETH back into the strategy
        uint256 remaining = IERC20(WSTETH).balanceOf(address(this));
        if (remaining > 0) {
            _invest(remaining, false);
        }
    }

    /**
     * @dev Invests a specified amount of assets into the strategy. Can only be called by the vault.
     * @param _amount The amount of assets to invest.
     */
    function invest(uint256 _amount) public onlyVault {
        // Internal function to handle the investment
        _invest(_amount, true);
    }

    /**
     * @dev Harvests strategy returns and reinvests to increase leverage.
     *      Can be called by the vault or the manager.
     */
    function harvest() public onlyVaultOrManager {
        // Withdraw all assets to the strategy
        _withdrawAllToStrategy();

        uint256 initialCollateral = IERC20(WSTETH).balanceOf(address(this));

        // Supply full strategy balance
        IPool(POOL).supply(
            WSTETH,
            initialCollateral,
            address(this),
            0
        );

        // Borrow against collateral
        IPool(POOL).borrow(
            WSTETH,
            _getBorrowAmount(initialCollateral),
            2,
            0,
            address(this)
        );

        // Re-invest into the vault to increase leverage
        IPool(POOL).supply(
            WSTETH, 
            IERC20(WSTETH).balanceOf(address(this)),
            address(this),
            0
        );
    }

    /**
     * @dev Sets the target ideal debt to collateral ratio. Can only be called by the manager.
     * @param _idealDebtToCollateral The new target ideal debt to collateral ratio.
     */
    function setDebtToCollateral(uint256 _idealDebtToCollateral) public onlyManager {
        idealDebtToCollateral = _idealDebtToCollateral;
    }

    /**
     * @dev Sets the manager address. Can only be called by the contract owner.
     * @param _manager The new manager address.
     */
    function setManager(address _manager) public onlyOwner {
        manager = _manager;
    }

    /**
     * @dev Previews the amount of assets that would be received upon withdrawal to the vault.
     * @param _assets The amount of assets to withdraw.
     * @return redeemAmount The estimated amount of assets to be received.
     */
    function previewWithdrawToVault(uint256 _assets) public view onlyVault returns(uint256) {
        // Calculate the estimated amount of assets to be received based on shares
        (uint256 assetsPerShareNumerator, uint256 assetsPerShareDenominator) = _assetsPerShare();
        if (assetsPerShareNumerator == 0 && assetsPerShareDenominator == 0) {
            return 0;
        }

        return _assets * assetsPerShareDenominator / assetsPerShareNumerator;
    }

    /**
     * @dev Previews the amount of assets that would be redeemed based on the given number of shares.
     * @param _shares The number of shares to redeem.
     * @return redeemAmount The estimated amount of assets to be redeemed.
     */
    function previewRedeem(uint256 _shares) public view onlyVault returns(uint256) {
        // Calculate the estimated amount of assets to be redeemed based on shares
        (uint256 assetsPerShareNumerator, uint256 assetsPerShareDenominator) = _assetsPerShare();
        if (assetsPerShareNumerator == 0 && assetsPerShareDenominator == 0) {
            return 0;
        }

        return _shares * assetsPerShareNumerator / assetsPerShareDenominator;
    }

    // INTERNAL FUNCTIONS

    /**
     * @dev Internal function to calculate the assets per share based on the strategy's collateral and debt.
     * @return assetsPerShareNumerator The numerator of the assets per share calculation.
     * @return assetsPerShareDenominator The denominator of the assets per share calculation.
     */
    function _assetsPerShare() internal view returns(uint256 assetsPerShareNumerator, uint256 assetsPerShareDenominator){
        //wstEthPerShare =  wstEthPerATok * aTokenPerEth * EthPerShare
        (uint collateralInEth, uint debtInEth ) = _getCollateralAndDebtInEth();
        uint netCollateral = collateralInEth - debtInEth;
        if(netCollateral == 0){
            return (0, 0);
        }

        uint aTokenBal = IERC20(A_TOKEN).balanceOf(address(this));
        uint wstEthInATokenContract = IERC20(WSTETH).balanceOf(address(A_TOKEN));
        uint aTokenTotalSupply = IERC20(A_TOKEN).totalSupply();
        uint totalVaultShares = IERC20(vault).totalSupply();

        uint256 numerator = wstEthInATokenContract * aTokenBal * netCollateral;
        uint256 denominator = aTokenTotalSupply * collateralInEth * totalVaultShares;
        return (numerator, denominator);
    }

    /**
     * @dev Internal function to withdraw all assets from the strategy to Aave.
     */
    function _withdrawAllToStrategy() internal {
        // Repay Aave with aTokens and withdraw all WSTETH from Aave to the strategy
        IPool(POOL).repayWithATokens(
            WSTETH, 
            IERC20(A_TOKEN).balanceOf(address(this)),
            2
        );

        IPool(POOL).withdraw(
            WSTETH, 
            IERC20(A_TOKEN).balanceOf(address(this)), address(this)
        );
    }

    /**
     * @dev Internal function to invest a specified amount of assets into the strategy.
     * @param _amount The amount of assets to invest.
     * @param _vaultCall A boolean indicating whether the call is from the vault.
     */
    function _invest(uint256 _amount, bool _vaultCall) internal {
        if(_vaultCall){
            // Move WSTETH funds from Vault to Strategy 
            IERC20(WSTETH).transferFrom(msg.sender, address(this), _amount);
        }
        
        // Loan WSTETH tokens to Aave 
        uint bal = IERC20(WSTETH).balanceOf(address(this));
        IPool(POOL).supply(WSTETH, bal, address(this), 0);

        // Borrow WSTETH tokens from Aave 
        uint256 initialCollateral = _aTokensToWstEth(IERC20(A_TOKEN).balanceOf(address(this)));
        uint256 borrowAmount = _getBorrowAmount(initialCollateral);

        IPool(POOL).borrow(
            WSTETH,
            borrowAmount,
            2,
            0,
            address(this)
        );

        // Re-invest into the vault to increase leverage
        bal = IERC20(WSTETH).balanceOf(address(this));
        IPool(POOL).supply(WSTETH, bal, address(this), 0);
    }
    
    /**
     * @dev Internal function to retrieve the max loan-to-value ratio from aave.
     * @return ltv The max loan-to-value ratio of the strategy.
     */
    function _getLtv() internal view returns(uint256){
        (,,,,uint256 ltv,) = IPool(POOL).getUserAccountData(address(this));
        return ltv;
    }

    /**
     * @dev Internal function to retrieve the collateral and debt in Ether of the strategy.
     * @return collateralInEth The amount of collateral in Ether.
     * @return debtInEth The amount of debt in Ether.
     */
    function _getCollateralAndDebtInEth() internal view returns(uint256, uint256){
        (uint256 collateral, uint256 debt,,,,) = IPool(POOL).getUserAccountData(address(this));
        return (collateral, debt);
    }

    /**
     * @dev Internal function to calculate the borrow amount based on the strategy's collateral.
     * @param _collateral The amount of collateral in Ether.
     * @return borrowAmount The calculated borrow amount.
     */
    function _getBorrowAmount(uint256 _collateral) internal view returns(uint256){
        uint256 borrow = (_collateral * idealDebtToCollateral) / (1000 - idealDebtToCollateral);
        uint256 maxBorrow = (_getLtv() * _collateral) / 10000;

        return (borrow <= maxBorrow)? borrow : maxBorrow;
    }

    /**
     * @dev Internal function to convert aTokens to WSTETH based on the strategy's aToken balance.
     * @param _aTokenAmount The amount of aTokens to convert.
     * @return wstEthAmount The calculated amount of WSTETH.
     */
    function _aTokensToWstEth(uint256 _aTokenAmount) internal view returns (uint256){
        uint256 totalWstEthInPool = IERC20(WSTETH).balanceOf(A_TOKEN);
        uint256 totalATokens = IERC20(A_TOKEN).totalSupply();

        return _aTokenAmount * totalWstEthInPool / totalATokens;
    }
}
