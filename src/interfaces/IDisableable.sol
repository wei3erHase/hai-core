// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IDisableable {
  function disableContract() external;
  function contractEnabled() external view returns (uint256 _enabled);
}