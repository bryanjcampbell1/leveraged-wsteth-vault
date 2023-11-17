// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IAToken} from "@aave/core-v3/contracts/interfaces/IAToken.sol";
import {IVariableDebtToken} from "@aave/core-v3/contracts/interfaces/IVariableDebtToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

contract AaveWrapper {
  address POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
  address WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
  address A_TOKEN = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;
  address V_DEBT = 0xC96113eED8cAB59cD8A66813bCB0cEb29F06D2e4;
  
  address public vault;
  uint256 public idealLeverage;

  constructor() {
      IERC20(WSTETH).approve(POOL, 2**256 - 1);
      IAToken(A_TOKEN).approve(POOL, 2**256 - 1);
  }

  // supply to recieve aTokens
  function supplyLeverage(uint256 _amount) public {
    IERC20(WSTETH).transferFrom(msg.sender, address(this), _amount);

    // Loan wstETH tokens to Aave 
    uint bal = IERC20(WSTETH).balanceOf(address(this));
    IPool(POOL).supply(WSTETH, bal, address(this), 0);

    //Borrow half 
    IPool(POOL).borrow(
        WSTETH,
        bal/2,
        2,
        0,
        address(this)
    );

    // Re-invest into the vault to increase leverage
    bal = IERC20(WSTETH).balanceOf(address(this));
    IPool(POOL).supply(WSTETH, bal, address(this), 0);
  }

  function withdrawAll() public {
    IPool(POOL).repayWithATokens(
      WSTETH, 
      IAToken(A_TOKEN).balanceOf(address(this)),
      2
    );

    IPool(POOL).withdraw(
      WSTETH, 
      IAToken(A_TOKEN).balanceOf(address(this)), address(this)
    );
  }

  function harvest() public {
    withdrawAll();

    uint256 debtToCollateral = 450; 
    uint256 initialCollateral = IERC20(WSTETH).balanceOf(address(this));

    // Supply full strategy balance
    IPool(POOL).supply(
      WSTETH,
      initialCollateral,
      address(this),
      0
    );

    //Borrow against collateral
    uint256 borrow = (initialCollateral * debtToCollateral) / (1000 - debtToCollateral);
    uint256 maxBorrow = (_getLtv() * initialCollateral) / 10000;

    IPool(POOL).borrow(
        WSTETH,
        (borrow <= maxBorrow)? borrow : maxBorrow,
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

  function _getLtv() internal view returns(uint256){
    (,,,,uint256 ltv,) = IPool(POOL).getUserAccountData(address(this));
    return ltv;
  }



}





    // (
    //   uint256 totalCollateralBase1,
    //   uint256 totalDebtBase1,
    //   ,
    //   ,
    //   ,
    // ) = IPool(POOL).getUserAccountData(address(this));

    // console.log("Collateral: ", totalCollateralBase1);
    // console.log("Debt: ", totalDebtBase1);

    // console.log("wstETH balance: ", IERC20(WSTETH).balanceOf(address(this)));



    // (
    //   uint256 totalCollateralBase,
    //   uint256 totalDebtBase,
    //   uint256 availableBorrowsBase,
    //   uint256 currentLiquidationThreshold,
    //   uint256 ltv,
    //   uint256 healthFactor
    // ) = IPool(POOL).getUserAccountData(msg.sender);

    // (
    //   uint256 totalCollateralBase2,
    //   uint256 totalDebtBase2,
    //   ,
    //   ,
    //   ,
      
    // ) = IPool(POOL).getUserAccountData(address(this));

    // console.log("totalCollateralBase: ", totalCollateralBase2);
    // console.log("totalDebtBase: ", totalDebtBase2);
    // console.log("wstETH balance: ", IERC20(WSTETH).balanceOf(address(this)));
