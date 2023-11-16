// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {StrategyController} from "./StrategyController.sol";

contract LeveragedWstEth is ERC4626, Pausable, StrategyController  {

  event Invest(uint256 amount);

  constructor(address underlying) 
  ERC20("Leveraged wstETH Vault", "LWSTETH") 
  ERC4626(IERC20(underlying)) 
  StrategyController(underlying)  
  {}

  // ADMIN
  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  function harvest() public onlyOwner whenStrategyDefined  {
    IStrategy(strategy).harvest();
  }


  // PUBLIC
  function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
      uint256 shares = previewDeposit(assets);

      // Mitigate inflation attack by not allowing shares to equal 0 
      require(shares > 0, "ERC4626: cannot mint 0 shares"); 

      _deposit(_msgSender(), receiver, assets, shares);
      _invest(assets);

      return shares;
  }

  /// @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
  function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
      return IStrategy(strategy).previewWithdrawToVault(assets);
  }

  // /// @dev Preview taking an exit fee on redeem. See {IERC4626-previewRedeem}.
  // function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
  //   //????
  // }

  // INTERNAL
  function _invest(uint256 amount) internal whenStrategyDefined {
    IStrategy(strategy).harvest();
    emit Invest(amount);

  }
}