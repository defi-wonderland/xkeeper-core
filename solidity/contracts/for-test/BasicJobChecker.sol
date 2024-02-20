// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IGelatoRelay} from '@interfaces/relays/IGelatoRelay.sol';
import {IBasicJobChecker, IAutomationVault, IBasicJob} from '@interfaces/for-test/IBasicJobChecker.sol';

/**
 * @notice This contract is a basic job checker for gelato relay
 * @dev This contract is for testing purposes only
 */
contract BasicJobChecker is IBasicJobChecker {
  /// @inheritdoc IBasicJobChecker
  function checker(
    IAutomationVault _automationVault,
    IBasicJob _basicJob
  ) external pure returns (bool _canExec, bytes memory _execPayload) {
    // Creates exec data for the automation vault
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);

    // Data will be encoded as the target address and the data to be executed
    _execData[0] = IAutomationVault.ExecData(address(_basicJob), abi.encodeWithSelector(IBasicJob.work.selector));

    // Creates exec payload for the relay
    _execPayload = abi.encodeCall(IGelatoRelay.exec, (_automationVault, _execData));

    // Returns true and the exec payload
    return (true, _execPayload);
  }
}
