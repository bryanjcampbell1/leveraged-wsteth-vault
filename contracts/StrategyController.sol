// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

// Inspired by harvest.finance Vault contract
contract StrategyController is Ownable {

  address public underlying;
  address public strategy;
  address public futureStrategy;
  uint256 public strategyUpdateTime;
  uint256 public strategyTimeLock;

  uint256 strategyChangeDelay = 12 hours;

  event StrategyAnnounced(address newStrategy, uint256 time);
  event StrategyChanged(address newStrategy, address oldStrategy);

  modifier whenStrategyDefined() {
    require(strategy != address(0), "Strategy must be defined");
    _;
  }

  constructor(address _underlying) Ownable(msg.sender) {
    underlying = _underlying;
  }

  // ADMIN FUNCTIONS
  function announceStrategyUpdate(address _strategy) public onlyOwner {
    // records a new timestamp
    uint256 when = block.timestamp + strategyTimeLock;
    _setStrategyUpdateTime(when);
    _setFutureStrategy(_strategy);
    emit StrategyAnnounced(_strategy, when);
  }

  function setStrategy(address _strategy) public onlyOwner {
    require(canUpdateStrategy(_strategy), "The strategy exists and switch timelock did not elapse yet");
    require(_strategy != address(0), "new _strategy cannot be empty");

    strategy = _strategy;
    emit StrategyChanged(_strategy, strategy);

    IERC20(underlying).approve(address(strategy), 2**256 - 1);

    _setStrategyUpdateTime(0);
    _setFutureStrategy(address(0));
  }

  function canUpdateStrategy(address _strategy) public view returns(bool) {
    return strategy == address(0) // no strategy was set yet
      || (_strategy == futureStrategy
          && block.timestamp > strategyUpdateTime
          && strategyUpdateTime > 0); // or the timelock has passed
  }

  // INTERNAL FUNCTIONS
  function _setStrategyTimeLock(uint256 _strategyTimeLock) internal {
    strategyTimeLock = _strategyTimeLock;
  }

  function _setFutureStrategy(address _futureStrategy) internal {
    futureStrategy =_futureStrategy;
  }

  function _setStrategyUpdateTime(uint256 _strategyUpdateTime) internal {
    strategyUpdateTime = _strategyUpdateTime;
  }

  function _setStrategy(address _strategy) internal {
    strategy =  _strategy;
  }
}
