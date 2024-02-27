// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IKeep3rBondedRelay, IAutomationVault, IKeep3rRelay} from '@interfaces/relays/IKeep3rBondedRelay.sol';
import {IKeep3rV2} from '@interfaces/relays/IKeep3rRelay.sol';

/**
 * @title  Keep3rBondedRelay
 * @notice This contract will manage all executions coming from the keep3r network when the job is bonded
 */
contract Keep3rBondedRelay is IKeep3rBondedRelay {
  /// @inheritdoc IKeep3rRelay
  IKeep3rV2 public immutable KEEP3R_V2;

  /**
   * @param _keep3rV2 The address of the keep3rV2 contract
   */
  constructor(IKeep3rV2 _keep3rV2) {
    KEEP3R_V2 = _keep3rV2;
  }

  /// @inheritdoc IKeep3rBondedRelay
  mapping(IAutomationVault _automationVault => IKeep3rBondedRelay.Requirements _bondRequirements) public
    automationVaultRequirements;

  /// @inheritdoc IKeep3rBondedRelay
  function setAutomationVaultRequirements(
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements calldata _requirements
  ) external {
    if (_automationVault.owner() != msg.sender) revert Keep3rBondedRelay_NotVaultOwner();

    automationVaultRequirements[_automationVault] = _requirements;
    emit AutomationVaultRequirementsSetted(
      _automationVault, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );
  }

  /// @inheritdoc IKeep3rRelay
  function exec(IAutomationVault _automationVault, IAutomationVault.ExecData[] calldata _execData) external {
    // Ensure that calls are being passed
    uint256 _execDataLength = _execData.length;
    if (_execDataLength == 0) revert Keep3rRelay_NoExecData();

    // Ensure that the automation vault owner has setup bond requirements
    IKeep3rBondedRelay.Requirements memory _requirements = automationVaultRequirements[_automationVault];
    if (_requirements.bond == address(0) && _requirements.earned == 0 && _requirements.age == 0) {
      revert Keep3rBondedRelay_NotAutomationVaultRequirement();
    }

    // The first call to `isBondedKeeper` ensures the caller is a valid bonded keeper.
    bool _isBondedKeeper = KEEP3R_V2.isBondedKeeper(
      msg.sender, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );
    if (!_isBondedKeeper) revert Keep3rBondedRelay_NotBondedKeeper();

    // Create the array of calls which are going to be executed by the automation vault
    IAutomationVault.ExecData[] memory _execDataKeep3r = new IAutomationVault.ExecData[](_execDataLength + 2);

    // The second call sets the initialGas variable inside Keep3r in the same deepness level than the `worked` call
    // If the second call is not done, the initialGas will have a 63/64 more gas than the `worked`, thus overpaying a lot
    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: address(KEEP3R_V2),
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, msg.sender)
    });

    // Inject to that array of calls the exec data provided in the arguments
    for (uint256 _i; _i < _execDataLength;) {
      if (_execData[_i].job == address(KEEP3R_V2)) revert Keep3rRelay_Keep3rNotAllowed();
      _execDataKeep3r[_i + 1] = _execData[_i];
      unchecked {
        ++_i;
      }
    }

    // Inject the final call which will issue the payment to the keeper
    _execDataKeep3r[_execDataLength + 1] = IAutomationVault.ExecData({
      job: address(KEEP3R_V2),
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, msg.sender)
    });

    // Send the array of calls to the automation vault for it to execute them
    _automationVault.exec(msg.sender, _execDataKeep3r, new IAutomationVault.FeeData[](0));

    // Emit necessary event
    emit AutomationVaultExecuted(_automationVault, msg.sender, _execDataKeep3r);
  }
}
