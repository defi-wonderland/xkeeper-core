// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IBasicJob} from '@interfaces/for-test/IBasicJob.sol';

/**
 * @notice This contract is a basic job that can be automated by any automation vault
 * @dev This contract is for testing purposes only
 */
contract BasicJob is IBasicJob {
  /**
   * @notice Mapping of the dataset
   * @dev This mapping is for test a job that uses a lot of gas
   */
  mapping(uint256 => address) internal _dataset;

  /**
   * @notice Nonce of the dataset
   * @dev This nonce is used to test a job which uses a lot of gas
   */
  uint256 internal _nonce;

  /// @inheritdoc IBasicJob
  function work() external {
    emit Worked();
  }

  /// @inheritdoc IBasicJob
  function workHard(uint256 _howHard) external {
    for (uint256 _i; _i < _howHard;) {
      _dataset[_nonce] = address(this);

      unchecked {
        ++_i;
        ++_nonce;
      }
    }
  }
}
