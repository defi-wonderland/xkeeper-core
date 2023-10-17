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
  mapping(address _automationVault => IKeep3rBondedRelay.Requirements _bondRequirements) public
    automationVaultRequirements;

  /// @inheritdoc IKeep3rBondedRelay
  function setAutomationVaultRequirements(
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) external {
    if (IAutomationVault(_automationVault).owner() != msg.sender) revert Keep3rBondedRelay_NotVaultOwner();

    automationVaultRequirements[_automationVault] =
      IKeep3rBondedRelay.Requirements({bond: _bond, minBond: _minBond, earned: _earned, age: _age});
    emit AutomationVaultRequirementsSetted(_automationVault, _bond, _minBond, _earned, _age);
  }

  /// @inheritdoc IKeep3rRelay
  function exec(address _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    IKeep3rBondedRelay.Requirements memory _requirements = automationVaultRequirements[_automationVault];

    if (_requirements.bond == address(0)) revert Keep3rBondedRelay_NotAutomationVaultRequirement();

    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 2);

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

    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == _KEEP3R_V2) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i + 1] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    _execDataKeep3r[_execDataLength + 1] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, msg.sender)
    });

    IAutomationVault(_automationVault).exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
