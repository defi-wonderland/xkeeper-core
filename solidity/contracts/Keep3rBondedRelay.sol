// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IKeep3rBondedRelay, IAutomationVault, IKeep3rRelay} from '@interfaces/IKeep3rBondedRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2} from '@utils/Constants.sol';

/**
 * @title  Keep3rBondedRelay
 * @notice This contract will manage all executions coming from the keep3r network when the job is bonded
 */
contract Keep3rBondedRelay is IKeep3rBondedRelay {
  /// @inheritdoc IKeep3rBondedRelay
  mapping(address _automationVault => IKeep3rBondedRelay.Requirements _bondRequirements) public
    automationVaultRequirements;

  /// @inheritdoc IKeep3rBondedRelay
  function setAutomationVaultRequirements(
    address _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) external {
    if (IAutomationVault(_automationVault).owner() != msg.sender) revert Keep3rBondedRelay_NotVaultOwner();

    automationVaultRequirements[_automationVault] = _requirements;
    emit AutomationVaultRequirementsSetted(
      _automationVault, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );
  }

  /// @inheritdoc IKeep3rRelay
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    // Ensure that calls are being passed
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    // Ensure that the automation vault owner has setup bond requirements
    IKeep3rBondedRelay.Requirements memory _requirements = automationVaultRequirements[_automationVault];
    if (_requirements.bond == address(0) && _requirements.earned == 0 && _requirements.age == 0) {
      revert Keep3rBondedRelay_NotAutomationVaultRequirement();
    }

    // Ensure that the keeper meets the requirements
    bool _isBondedKeeper = IKeep3rV2(_KEEP3R_V2).isBondedKeeper(
      msg.sender, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );
    if (!_isBondedKeeper) revert Keep3rBondedRelay_NotBondedKeeper();

    // Create the array of calls which are going to be executed by the automation vault
    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 2);

    // Inject the first call which will validate that the caller is a bonded keeper
    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(
        IKeep3rV2.isBondedKeeper.selector,
        msg.sender,
        _requirements.bond,
        _requirements.minBond,
        _requirements.earned,
        _requirements.age
        )
    });

    // Inject to that array of calls the exec data provided in the arguments
    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == _KEEP3R_V2) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i + 1] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    // Inject the final call which will issue the payment to the keeper
    _execDataKeep3r[_execDataLength + 1] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, msg.sender)
    });

    // Send the array of calls to the automation vault for it to execute them
    IAutomationVault(_automationVault).exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    // Emit necessary event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
