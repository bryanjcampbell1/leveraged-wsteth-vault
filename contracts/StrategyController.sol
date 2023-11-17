// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

// Inspired by harvest.finance Vault contract
/**
 * @title StrategyController
 * @dev A smart contract that manages the strategy for vault.
 */
contract StrategyController is Ownable {

  // Address of the underlying token
  address public underlying;

  // Current strategy contract
  address public strategy;

  // Future strategy contract to be set
  address public futureStrategy;

  // Timestamp when the strategy can be updated
  uint256 public strategyUpdateTime;

  // Time lock for updating the strategy
  uint256 public strategyTimeLock;

  // Delay for changing the strategy to prevent flash loans and attacks
  uint256 strategyChangeDelay = 12 hours;

  // Event emitted when a new strategy is announced
  event StrategyAnnounced(address newStrategy, uint256 time);

  // Event emitted when the strategy is changed
  event StrategyChanged(address newStrategy, address oldStrategy);

  // Modifier to check if a strategy is defined
  modifier whenStrategyDefined() {
    require(strategy != address(0), "Strategy must be defined");
    _;
  }

  /**
   * @dev Constructor function to initialize the StrategyController.
   * @param _underlying Address of the underlying token.
   */
  constructor(address _underlying) Ownable(msg.sender) {
    underlying = _underlying;
  }

  // ADMIN FUNCTIONS

  /**
   * @dev Announces a new strategy update. Only callable by the owner.
   * @param _strategy The address of the new strategy.
   */
  function announceStrategyUpdate(address _strategy) public onlyOwner {
    // Records a new timestamp
    uint256 when = block.timestamp + strategyTimeLock;
    _setStrategyUpdateTime(when);
    _setFutureStrategy(_strategy);
    emit StrategyAnnounced(_strategy, when);
  }

  /**
   * @dev Sets a new strategy. Only callable by the owner.
   * @param _strategy The address of the new strategy.
   */
  function setStrategy(address _strategy) public onlyOwner {
    require(canUpdateStrategy(_strategy), "The strategy exists and switch timelock did not elapse yet");
    require(_strategy != address(0), "New strategy cannot be empty");

    strategy = _strategy;
    emit StrategyChanged(_strategy, strategy);

    IERC20(underlying).approve(address(strategy), 2**256 - 1);

    _setStrategyUpdateTime(0);
    _setFutureStrategy(address(0));
  }

  // PUBLIC FUNCTIONS
  
  /**
   * @dev Checks if the strategy can be updated.
   * @param _strategy The address of the new strategy.
   * @return Whether the strategy can be updated.
   */
  function canUpdateStrategy(address _strategy) public view returns(bool) {
    return strategy == address(0) // No strategy was set yet
      || (_strategy == futureStrategy
          && block.timestamp > strategyUpdateTime
          && strategyUpdateTime > 0); // or the timelock has passed
  }

  // INTERNAL FUNCTIONS

  /**
   * @dev Sets the strategy time lock.
   * @param _strategyTimeLock The new strategy time lock.
   */
  function _setStrategyTimeLock(uint256 _strategyTimeLock) internal {
    strategyTimeLock = _strategyTimeLock;
  }

  /**
   * @dev Sets the future strategy to be activated.
   * @param _futureStrategy The address of the future strategy.
   */
  function _setFutureStrategy(address _futureStrategy) internal {
    futureStrategy = _futureStrategy;
  }

  /**
   * @dev Sets the strategy update time.
   * @param _strategyUpdateTime The new strategy update time.
   */
  function _setStrategyUpdateTime(uint256 _strategyUpdateTime) internal {
    strategyUpdateTime = _strategyUpdateTime;
  }

  /**
   * @dev Sets the current strategy.
   * @param _strategy The address of the strategy.
   */
  function _setStrategy(address _strategy) internal {
    strategy = _strategy;
  }
}
