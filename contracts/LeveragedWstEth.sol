// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {StrategyController} from "./StrategyController.sol";


/**
 * @title LeveragedWstEth
 * @dev A smart contract implementing a leveraged wstETH vault with ERC4626 functionalities.
 */
contract LeveragedWstEth is ERC4626, Pausable, StrategyController  {

  // Address of the wstETH token
  address public constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

  // Event emitted when an investment is made
  event Invest(uint256 amount);

  /**
   * @dev Constructor function to initialize the leveraged wstETH vault.
   */
  constructor() 
  ERC20("Leveraged wstETH Vault", "LWSTETH") 
  ERC4626(IERC20(WSTETH)) 
  StrategyController(WSTETH)  
  {}

  // ADMIN

  /**
   * @dev Pauses the contract. Only callable by the owner.
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @dev Unpauses the contract. Only callable by the owner.
   */
  function unpause() public onlyOwner {
    _unpause();
  }

  /**
   * @dev Harvests rewards from the strategy. Only callable by the owner when strategy is defined.
   */
  function harvest() public onlyOwner whenStrategyDefined  {
    IStrategy(strategy).harvest();
  }

  // PUBLIC

  /**
   * @dev Deposits assets into the vault and mints shares. Only callable when not paused.
   * @param assets The amount of assets to deposit.
   * @param receiver The address to receive the shares.
   * @return shares The number of shares minted.
   */
  function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
    uint256 shares = previewDeposit(assets);

    // Mitigate inflation attack by not allowing shares to equal 0 
    require(shares > 0, "ERC4626: cannot mint 0 shares"); 

    _deposit(_msgSender(), receiver, assets, shares);
    _invest(assets);

    return shares;
  }

  /**
   * @dev Mints shares for the specified amount of assets. Only callable by the owner.
   * @param shares The number of shares to mint.
   * @param receiver The address to receive the shares.
   * @return assets The amount of assets minted.
   */
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

  /**
   * @dev Previews the amount of assets that can be withdrawn for a given amount of assets.
   * @param assets The amount of assets to withdraw.
   * @return The previewed amount of withdrawn assets.
   */
  function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
      return IStrategy(strategy).previewWithdrawToVault(assets);
  }

  /**
   * @dev Withdraws assets from the vault. Only callable when not paused.
   * @param assets The amount of assets to withdraw.
   * @param receiver The address to receive the withdrawn assets.
   * @param owner The owner's address.
   * @return shares The number of shares withdrawn.
   */
  function withdraw(uint256 assets, address receiver, address owner)  public override whenNotPaused returns (uint256) {
    uint256 shares = previewWithdraw(assets);
    IStrategy(strategy).withdrawToVault(assets);

    _withdraw(_msgSender(), receiver, owner, assets, shares);

    return shares;
  }

  /**
   * @dev Previews the amount of assets that can be redeemed for a given amount of shares.
   * @param shares The number of shares to redeem.
   * @return The previewed amount of redeemed assets.
   */
  function previewRedeem(uint256 shares) public view override returns (uint256) {
    return IStrategy(strategy).previewRedeem(shares);
  }

  /**
   * @dev Retrieves the total assets under management in the vault.
   * @return The total assets under management.
   */
  function totalAssets() public view override returns (uint256) {
    return previewRedeem(totalSupply());
  }

  /**
   * @dev Redeems shares for the specified amount of assets. Only callable by the owner.
   * @param shares The number of shares to redeem.
   * @param receiver The address to receive the redeemed assets.
   * @param owner The owner's address.
   * @return assets The amount of assets redeemed.
   */
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

  /**
   * @dev Invests the specified amount in the strategy. Only callable when the strategy is defined.
   * @param amount The amount to invest.
   */
  function _invest(uint256 amount) internal whenStrategyDefined {
    IStrategy(strategy).invest(amount);
    emit Invest(amount);
  }
}
