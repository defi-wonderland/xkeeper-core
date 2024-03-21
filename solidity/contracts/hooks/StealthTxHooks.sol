// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IStealthVault} from '@interfaces/external/IStealthVault.sol';
import {IStealthRelayer} from '@interfaces/external/IStealthRelayer.sol';

contract StealthTxYearnHooks {
  IStealthVault public stealthVault;
  IStealthRelayer public stealthRelayer;

  constructor(IStealthVault _stealthVault, IStealthRelayer _stealthRelayer) {
    stealthVault = _stealthVault;
    stealthRelayer = _stealthRelayer;
  }

  // todo: impossible to set caller = msg.sender
  // todo: need to perform call with value
  // todo: need find a way to make paymnets for block.coinbase
  function validateCall(
    address _job,
    address _caller,
    bytes memory _calldata,
    bytes32 _hash,
    uint256 _blockNumber,
    uint256 _penalty
  ) external payable returns (bytes memory) {
    // check if the job in the job list
    address[] memory _jobs = stealthRelayer.jobs();
    for (uint256 i = 0; i < _jobs.length; i++) {
      if (_jobs[i] == _job) {
        break;
      }
      if (i == _jobs.length - 1) {
        revert('SR: invalid job');
      }
    }

    bool _isValidHash = stealthVault.validateHash(_caller, _hash, _penalty);
    require(_isValidHash, 'ST: invalid stealth hash');

    require(block.number == _blockNumber, 'ST: wrong block');

    return _calldata;
  }

  function validateCallWithoutBlock(
    address _job,
    address _caller,
    bytes memory _calldata,
    bytes32 _hash,
    uint256 _penalty
  ) external payable returns (bytes memory) {
    // check if the job in the job list
    address[] memory _jobs = stealthRelayer.jobs();
    for (uint256 i = 0; i < _jobs.length; i++) {
      if (_jobs[i] == _job) {
        break;
      }
      if (i == _jobs.length - 1) {
        revert('SR: invalid job');
      }
    }

    bool _isValidHash = stealthVault.validateHash(_caller, _hash, _penalty);
    require(_isValidHash, 'ST: invalid stealth hash');

    require(!stealthRelayer.forceBlockProtection(), 'SR: block protection required');

    return _calldata;
  }
}
