// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import "hardhat/console.sol";

contract AaveStrategy is IStrategy, Ownable {

    address POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address A_TOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
    address V_DEBT = 0xC96113eED8cAB59cD8A66813bCB0cEb29F06D2e4;

    address public vault;
    address public manager;
    uint256 public idealDebtToCollateral;

    modifier onlyVault() {
        require(vault == msg.sender, "Can only be called by vault");
        _;
    }

    modifier onlyManager() {
        require(manager == msg.sender, "Can only be called by manager");
        _;
    }

    modifier onlyVaultOrManager() {
        require(vault == msg.sender || manager == msg.sender, "Can only be called by vault or manager");
        _;
    }

    constructor(address _vault, address _manager, uint256 _idealDebtToCollateral) Ownable(msg.sender){
        vault = _vault;
        manager = _manager;
        idealDebtToCollateral = _idealDebtToCollateral;
        IERC20(WSTETH).approve(POOL, 2**256 - 1);
        IERC20(A_TOKEN).approve(POOL, 2**256 - 1);
    }

    // Called by manager or vault. Used to prepare vault for new strategy.
    function withdrawAllToVault() public onlyVaultOrManager {
        _withdrawAllToStrategy();

        IERC20(WSTETH).transfer(
            vault,
            IERC20(WSTETH).balanceOf(address(this))
        );
    }

    // Called on user withdrawal
    function redeem(uint256 _amountOfShares) public onlyVault returns(uint256){
        _withdrawAllToStrategy();

        uint256 totalWstEth = IERC20(WSTETH).balanceOf(address(this));
        uint256 totalVaultShares = IERC20(vault).totalSupply();

        uint256 withdrawAmount = _amountOfShares * totalWstEth / totalVaultShares;

        IERC20(WSTETH).transfer(
            vault,
            withdrawAmount
        );

        return withdrawAmount;
    }

    function withdrawToVault(uint256 _assets) public onlyVault {
        _withdrawAllToStrategy();

        uint256 totalWstEth = IERC20(WSTETH).balanceOf(address(this));

        console.log("_assets: ", _assets);
        console.log("totalWstEth: ", totalWstEth);

        require(totalWstEth > _assets, "Not enough tokens in strategy"); 

        IERC20(WSTETH).transfer(
            vault,
            _assets
        );

    }

    function invest(uint256 _amount) public onlyVault {
        // Move wstETH funds from Vault to Strategy 
        IERC20(WSTETH).transferFrom(msg.sender, address(this), _amount);

        // Loan wstETH tokens to Aave 
        uint bal = IERC20(WSTETH).balanceOf(address(this));
        IPool(POOL).supply(WSTETH, bal, address(this), 0);

        // Borrow wstETH tokens from Aave 
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

    function harvest() public onlyVaultOrManager {
        _withdrawAllToStrategy();

        uint256 initialCollateral = IERC20(WSTETH).balanceOf(address(this));

        // Supply full strategy balance
        IPool(POOL).supply(
        WSTETH,
        initialCollateral,
        address(this),
        0
        );

        //Borrow against collateral
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

    function harvest2() public onlyVaultOrManager {

        (uint collateralInEth, uint debtInEth ) = _getCollateralAndDebtInEth();
        uint256 actualDebtToCollateral = 1000 * debtInEth / collateralInEth;

        if(idealDebtToCollateral > actualDebtToCollateral){
            // Risk On! Borrow ETH and redeposit wstETH

            // Actually this is borrowAmountInEth --> need to convert to wstETH
            uint256 borrowAmount = (idealDebtToCollateral - actualDebtToCollateral) * collateralInEth;

            // or check if we have hit max borrow ratio

            IPool(POOL).borrow(
                WSTETH,
                borrowAmount,
                2,
                0,
                address(this)
            );

            uint bal = IERC20(WSTETH).balanceOf(address(this));

            IPool(POOL).supply(WSTETH, bal, address(this), 0);

        } else if(idealDebtToCollateral < actualDebtToCollateral){
            // Risk off! Repay loan to lower leverage

            // Actually this is borrowAmountInEth --> need to convert to wstETH
            uint256 repayAmount = ((idealDebtToCollateral * collateralInEth) - (1000 * debtInEth)) /  idealDebtToCollateral;
            IPool(POOL).repay(WSTETH, repayAmount, 2, address(this));
            
        } else{
            return;
        }

    }

    function setDebtToCollateral(uint256 _idealDebtToCollateral) public onlyManager {
        idealDebtToCollateral = _idealDebtToCollateral;
    }

    function setManager(address _manager) public onlyOwner {
        manager = _manager;
    }

    function previewWithdrawToVault(uint256 _assets) public view onlyVault  returns(uint256) {
        // How get total shares burned for _assets fo wstEth?

        // sharePerWstEth = sharePerEth  * ethPerATok * aTokPerWstEth 
        // totalSharesBurned = _assets * sharePerWstEth = _assets * aTokPerWstEth * ethPerATok * sharesPerEth

        (uint collateralInEth, uint debtInEth ) = _getCollateralAndDebtInEth();

        uint netCollateral = collateralInEth - debtInEth;
        uint aTokenBal = IERC20(A_TOKEN).balanceOf(address(this));
        uint wstEthInATokenContract = IERC20(WSTETH).balanceOf(address(A_TOKEN));
        uint aTokenTotalSupply = IERC20(A_TOKEN).totalSupply();
        uint totalVaultShares = IERC20(vault).totalSupply();

        return (_assets * aTokenTotalSupply * collateralInEth * totalVaultShares ) / (wstEthInATokenContract * aTokenBal * netCollateral);
    }

    // INTERNAL 
    function _withdrawAllToStrategy() internal {
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

    function _getLtv() internal view returns(uint256){
        (,,,,uint256 ltv,) = IPool(POOL).getUserAccountData(address(this));
        return ltv;
    }

    function _getCollateralAndDebtInEth() internal view returns(uint256, uint256){
        (uint256 collateral,uint256 debt,,,,) = IPool(POOL).getUserAccountData(address(this));
        return (collateral, debt);
    }

    function _getBorrowAmount(uint256 _collateral) internal view returns(uint256){

        uint256 borrow = (_collateral * idealDebtToCollateral) / (1000 - idealDebtToCollateral);
        uint256 maxBorrow = (_getLtv() * _collateral) / 10000;

        return (borrow <= maxBorrow)? borrow : maxBorrow;
    }

    function _aTokensToWstEth(uint256 _aTokenAmount) internal view returns (uint256){
        uint256 totalWstEthInPool = IERC20(WSTETH).balanceOf(A_TOKEN);
        uint256 totalATokens = IERC20(A_TOKEN).totalSupply();

        return _aTokenAmount * totalWstEthInPool / totalATokens;
    }

}
