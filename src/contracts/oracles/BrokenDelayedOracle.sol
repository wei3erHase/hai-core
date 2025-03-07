// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;
/*
  by             .__________                 ___ ___
  __  _  __ ____ |__\_____  \  ___________  /   |   \_____    ______ ____
  \ \/ \/ // __ \|  | _(__  <_/ __ \_  __ \/    ~    \__  \  /  ___// __ \
   \     /\  ___/|  |/       \  ___/|  | \/\    Y    // __ \_\___ \\  ___/
    \/\_/  \___  >__/______  /\___  >__|    \___|_  /(____  /____  >\___  >
               \/          \/     \/              \/      \/     \/     \/*/

import {IBaseOracle} from '@interfaces/oracles/IBaseOracle.sol';
import {IDelayedOracle} from '@interfaces/oracles/IDelayedOracle.sol';

/**
 * @title  BrokenDelayedOracle
 * @notice Causes a revert on every interaction
 * @dev    Used to disable the collateral and oracle update pipeline
 */
contract BrokenDelayedOracle is IBaseOracle, IDelayedOracle {
  // --- Registry ---

  // --- Errors ---
  error BrokenDelayedOracle_Reverts();

  /// @inheritdoc IDelayedOracle
  function updateResult() external pure returns (bool) {
    revert BrokenDelayedOracle_Reverts();
  }

  // --- Getters ---

  /// @inheritdoc IBaseOracle
  function symbol() external pure returns (string memory _symbol) {
    return 'BROKEN';
  }

  /// @inheritdoc IBaseOracle
  function getResultWithValidity() external pure returns (uint256 _result, bool _validity) {
    return (0, false);
  }

  /// @inheritdoc IBaseOracle
  function read() external pure returns (uint256) {
    revert BrokenDelayedOracle_Reverts();
  }

  /// @inheritdoc IDelayedOracle
  function shouldUpdate() external pure returns (bool _ok) {
    return false;
  }

  /// @inheritdoc IDelayedOracle
  function getNextResultWithValidity() external pure returns (uint256 _result, bool _validity) {
    return (0, false);
  }

  /// @inheritdoc IDelayedOracle
  function updateDelay() external pure returns (uint256 _updateDelay) {
    return 0;
  }

  /// @inheritdoc IDelayedOracle
  function lastUpdateTime() external view returns (uint256 _lastUpdateTime) {
    return block.timestamp;
  }

  /// @inheritdoc IDelayedOracle
  function priceSource() external view returns (IBaseOracle _priceSource) {
    return IBaseOracle(address(this));
  }
}
