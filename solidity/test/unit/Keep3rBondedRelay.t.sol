// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {
  Keep3rBondedRelay,
  IKeep3rRelay,
  IKeep3rBondedRelay,
  IAutomationVault,
  IKeep3rV2
} from '@contracts/relays/Keep3rBondedRelay.sol';

contract Keep3rBondedRelayForTest is Keep3rBondedRelay {
  constructor(IKeep3rV2 _keep3rV2) Keep3rBondedRelay(_keep3rV2) {}

  function setAutomationVaultRequirementsForTest(
    IAutomationVault _automationVault,
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
    IAutomationVault indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  event AutomationVaultRequirementsSetted(
    IAutomationVault indexed _automationVault, address _bond, uint256 _minBond, uint256 _earned, uint256 _age
  );

  // Keep3rBondedRelay contract
  Keep3rBondedRelayForTest public keep3rBondedRelay;

  // Keep3rV2 contract
  IKeep3rV2 public keep3rV2;

  function setUp() public virtual {
    keep3rV2 = IKeep3rV2(makeAddr('KEEP3R_V2'));
    keep3rBondedRelay = new Keep3rBondedRelayForTest(keep3rV2);
  }
}

contract UnitKeep3rRelaySetAutomationVaultRequirements is Keep3rBondedRelayUnitTest {
  modifier happyPath(
    address _owner,
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) {
    vm.assume(address(_automationVault) != address(vm));
    vm.assume(
      _requirements.bond > address(0) && _requirements.minBond > 0 && _requirements.earned > 0 && _requirements.age > 0
    );
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.owner.selector), abi.encode(_owner));
    vm.startPrank(_owner);
    _;
  }

  function testRevertIfCallerIsNotAutomationVaultOwner(
    address _relayCaller,
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _requirements) {
    vm.expectRevert(IKeep3rBondedRelay.Keep3rBondedRelay_NotVaultOwner.selector);
    changePrank(makeAddr('notOwner'));

    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _requirements);
  }

  function testRequirementsWithCorrectsParams(
    address _relayCaller,
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _requirements) {
    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _requirements);
    (address _expectedBond, uint256 _expectedMinBond, uint256 _expectedEarned, uint256 _expectedAge) =
      keep3rBondedRelay.automationVaultRequirements(_automationVault);

    assertEq(_expectedBond, _requirements.bond);
    assertEq(_expectedMinBond, _requirements.minBond);
    assertEq(_expectedEarned, _requirements.earned);
    assertEq(_expectedAge, _requirements.age);
  }

  function testEmitSetAutomationVaultRequirements(
    address _relayCaller,
    IAutomationVault _automationVault,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _requirements) {
    vm.expectEmit();
    emit AutomationVaultRequirementsSetted(
      _automationVault, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );

    keep3rBondedRelay.setAutomationVaultRequirements(_automationVault, _requirements);
  }
}

contract UnitKeep3rBondedRelayExec is Keep3rBondedRelayUnitTest {
  modifier happyPath(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) {
    assumeNoPrecompiles(address(_automationVault));
    vm.assume(address(_automationVault) != address(vm));
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());
    vm.assume(
      _requirements.bond > address(0) && _requirements.minBond > 0 && _requirements.earned > 0 && _requirements.age > 0
    );
    keep3rBondedRelay.setAutomationVaultRequirementsForTest(
      _automationVault, _requirements.bond, _requirements.minBond, _requirements.earned, _requirements.age
    );

    vm.mockCall(
      address(keep3rV2),
      abi.encodeWithSelector(
        IKeep3rV2.isBondedKeeper.selector,
        _relayCaller,
        _requirements.bond,
        _requirements.minBond,
        _requirements.earned,
        _requirements.age
      ),
      abi.encode(true)
    );

    vm.assume(_execData.length > 0 && _execData.length < 30);
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.assume(_execData[_i].job != address(keep3rV2));
    }

    vm.startPrank(_relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NoExecData.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testRevertIfRequirementsAreNotSetted(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    keep3rBondedRelay.setAutomationVaultRequirementsForTest(_automationVault, address(0), 0, 0, 0);

    vm.expectRevert(IKeep3rBondedRelay.Keep3rBondedRelay_NotAutomationVaultRequirement.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testRevertIfCallerIsNotBondedKeep3r(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    address _newCaller = makeAddr('newCaller');
    changePrank(_newCaller);

    vm.mockCall(
      address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isBondedKeeper.selector, _newCaller), abi.encode(false)
    );
    vm.expectRevert(IKeep3rBondedRelay.Keep3rBondedRelay_NotBondedKeeper.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testRevertIfExecDataContainsKeep3rV2(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    vm.assume(_execData.length > 3);
    _execData[1].job = address(keep3rV2);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_Keep3rNotAllowed.selector);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    IAutomationVault.ExecData[] memory _execDataKeep3rBonded = _buildExecDataKeep3rBonded(_relayCaller, _execData);
    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(
        IAutomationVault.exec.selector, _relayCaller, _execDataKeep3rBonded, new IAutomationVault.FeeData[](0)
      )
    );

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData,
    IKeep3rBondedRelay.Requirements memory _requirements
  ) public happyPath(_relayCaller, _automationVault, _execData, _requirements) {
    IAutomationVault.ExecData[] memory _execDataKeep3rBonded = _buildExecDataKeep3rBonded(_relayCaller, _execData);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execDataKeep3rBonded);

    keep3rBondedRelay.exec(_automationVault, _execData);
  }

  function _buildExecDataKeep3rBonded(
    address _relayCaller,
    IAutomationVault.ExecData[] memory _execData
  ) internal view returns (IAutomationVault.ExecData[] memory _execDataKeep3rBonded) {
    uint256 _execDataKeep3rLength = _execData.length + 2;
    _execDataKeep3rBonded = new IAutomationVault.ExecData[](_execDataKeep3rLength);

    _execDataKeep3rBonded[0] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller)
    });

    for (uint256 _i; _i < _execData.length; ++_i) {
      _execDataKeep3rBonded[_i + 1] = _execData[_i];
    }

    _execDataKeep3rBonded[_execData.length + 1] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, _relayCaller)
    });
  }
}
