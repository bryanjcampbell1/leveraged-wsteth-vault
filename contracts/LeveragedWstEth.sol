// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {StrategyController} from "./StrategyController.sol";
import "hardhat/console.sol";

contract LeveragedWstEth is ERC4626, Pausable, StrategyController  {

  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

  event Invest(uint256 amount);

  constructor() 
  ERC20("Leveraged wstETH Vault", "LWSTETH") 
  ERC4626(IERC20(WSTETH)) 
  StrategyController(WSTETH)  
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

  function mint(uint256 shares, address receiver) public override returns (uint256) {
      uint256 maxShares = maxMint(receiver);
      if (shares > maxShares) {
          revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
      }

      uint256 assets = previewMint(shares);
      _deposit(_msgSender(), receiver, assets, shares);
      _invest(assets);

      return assets;
  }

  function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
      return IStrategy(strategy).previewWithdrawToVault(assets);
  }

  function withdraw(uint256 assets, address receiver, address owner)  public override whenNotPaused returns (uint256) {
    uint256 shares = previewWithdraw(assets);
    IStrategy(strategy).withdrawToVault(assets);

    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  function previewRedeem(uint256 shares) public view override returns (uint256) {
    return IStrategy(strategy).previewRedeem(shares);
  }

  function totalAssets() public view override returns (uint256) {
    return previewRedeem(totalSupply());
  }

  function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
      uint256 maxShares = maxRedeem(owner);
      if (shares > maxShares) {
          revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
      }

      uint256 assets = previewRedeem(shares);
      IStrategy(strategy).redeem(shares);
      _withdraw(_msgSender(), receiver, owner, assets, shares);

      return assets;
  }

  // INTERNAL
  function _invest(uint256 amount) internal whenStrategyDefined {
    IStrategy(strategy).invest(amount);
    emit Invest(amount);
  }
}
