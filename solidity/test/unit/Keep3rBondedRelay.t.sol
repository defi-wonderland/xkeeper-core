// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Keep3rBondedRelay, IKeep3rRelay, IKeep3rBondedRelay, IAutomationVault} from '@contracts/Keep3rBondedRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2} from '@utils/Constants.sol';

contract Keep3rBondedRelayForTest is Keep3rBondedRelay {
  function setAutomationVaultRequirementsForTest(
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) external {
    automationVaultRequirements[_automationVault] =
      IKeep3rBondedRelay.Requirements({bond: _bond, minBond: _minBond, earned: _earned, age: _age});
  }
}

/**
 * @title Keep3rBondedRelay Unit tests
 */
contract Keep3rBondedRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    address indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  event AutomationVaultRequirementsSetted(
    address indexed _automationVault, address _bond, uint256 _minBond, uint256 _earned, uint256 _age
  );

  // Keep3rBondedRelay contract
  Keep3rBondedRelayForTest public keep3rBondedRelay;

  function setUp() public virtual {
    keep3rBondedRelay = new Keep3rBondedRelayForTest();
  }
}

contract UnitKeep3rRelaySetAutomationVaultRequirements is Keep3rBondedRelayUnitTest {
  modifier happyPath(
    address _owner,
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) {
    vm.assume(_automationVault != address(vm));
    vm.assume(_bond > address(0) && _minBond > 0 && _earned > 0 && _age > 0);
    vm.mockCall(_automationVault, abi.encodeWithSelector(IAutomationVault.owner.selector), abi.encode(_owner));
    vm.startPrank(_owner);
    _;
  }

  function testRevertIfCallerIsNotAutomationVaultOwner(
    address _relayCaller,
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _bond, _minBond, _earned, _age) {
    vm.expectRevert(IKeep3rBondedRelay.Keep3rBondedRelay_NotVaultOwner.selector);
    changePrank(makeAddr('notOwner'));

    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _bond, _minBond, _earned, _age);
  }

  function testRequirementsWithCorrectsParams(
    address _relayCaller,
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _bond, _minBond, _earned, _age) {
    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _bond, _minBond, _earned, _age);
    (address _expectedBond, uint256 _expectedMinBond, uint256 _expectedEarned, uint256 _expectedAge) =
      keep3rBondedRelay.automationVaultRequirements(_automationVault);

    assertEq(_expectedBond, _bond);
    assertEq(_expectedMinBond, _minBond);
    assertEq(_expectedEarned, _earned);
    assertEq(_expectedAge, _age);
  }

  function testEmitSetAutomationVaultRequirements(
    address _relayCaller,
    address _automationVault,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _bond, _minBond, _earned, _age) {
    vm.expectEmit();
    emit AutomationVaultRequirementsSetted(_automationVault, _bond, _minBond, _earned, _age);

    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _bond, _minBond, _earned, _age);
  }
}

contract UnitKeep3rBondedRelayExec is Keep3rBondedRelayUnitTest {
  modifier happyPath(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) {
    assumeNoPrecompiles(_automationVault);
    vm.assume(_automationVault != address(vm));
    vm.mockCall(_automationVault, abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());
    vm.assume(_bond > address(0) && _minBond > 0 && _earned > 0 && _age > 0);
    keep3rBondedRelay.setAutomationVaultRequirementsForTest(_automationVault, _bond, _minBond, _earned, _age);

    vm.assume(_execData.length > 0 && _execData.length < 30);
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.assume(_execData[_i].job != _KEEP3R_V2);
    }

    vm.startPrank(_relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _execData, _bond, _minBond, _earned, _age) {
    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NoExecData.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testRevertIfRequirementsAreNotSetted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _execData, _bond, _minBond, _earned, _age) {
    keep3rBondedRelay.setAutomationVaultRequirementsForTest(_automationVault, address(0), 0, 0, 0);

    vm.expectRevert(IKeep3rBondedRelay.Keep3rBondedRelay_NotAutomationVaultRequirement.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testRevertIfExecDataContainsKeep3rV2(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _execData, _bond, _minBond, _earned, _age) {
    vm.assume(_execData.length > 3);
    _execData[1].job = _KEEP3R_V2;

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_Keep3rNotAllowed.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _execData, _bond, _minBond, _earned, _age) {
    IAutomationVault.ExecData[] memory _execDataKeep3rBonded =
      _buildExecDataKeep3rBonded(_relayCaller, _execData, _bond, _minBond, _earned, _age);
    vm.expectCall(
      _automationVault,
      abi.encodeWithSelector(
        IAutomationVault.exec.selector, _relayCaller, _execDataKeep3rBonded, new IAutomationVault.FeeData[](0)
      )
    );

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    address _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) public happyPath(_relayCaller, _automationVault, _execData, _bond, _minBond, _earned, _age) {
    IAutomationVault.ExecData[] memory _execDataKeep3rBonded =
      _buildExecDataKeep3rBonded(_relayCaller, _execData, _bond, _minBond, _earned, _age);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execDataKeep3rBonded);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function _buildExecDataKeep3rBonded(
    address _relayCaller,
    IAutomationVault.ExecData[] memory _execData,
    address _bond,
    uint256 _minBond,
    uint256 _earned,
    uint256 _age
  ) internal pure returns (IAutomationVault.ExecData[] memory _execDataKeep3rBonded) {
    uint256 _execDataKeep3rLength = _execData.length + 2;
    _execDataKeep3rBonded = new IAutomationVault.ExecData[](_execDataKeep3rLength);

    _execDataKeep3rBonded[0] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.isBondedKeeper.selector, _relayCaller, _bond, _minBond, _earned, _age)
    });

    for (uint256 _i; _i < _execData.length; ++_i) {
      _execDataKeep3rBonded[_i + 1] = _execData[_i];
    }

    _execDataKeep3rBonded[_execDataKeep3rLength - 1] = IAutomationVault.ExecData({
      job: _KEEP3R_V2,
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, _relayCaller)
    });
  }
}
