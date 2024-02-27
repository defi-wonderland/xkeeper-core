// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {Keep3rRelay, IKeep3rRelay, IAutomationVault} from '@contracts/relays/Keep3rRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';

/**
 * @title Keep3rRelay Unit tests
 */
contract Keep3rRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    IAutomationVault indexed _automationVault, address indexed _relayCaller, IAutomationVault.ExecData[] _execData
  );

  // Keep3rRelay contract
  Keep3rRelay public keep3rRelay;

  // Keep3r V2 contract
  IKeep3rV2 public keep3rV2;

  function setUp() public virtual {
    keep3rV2 = IKeep3rV2(makeAddr('KEEP3R_V2'));
    keep3rRelay = new Keep3rRelay(keep3rV2);
  }
}

contract UnitKeep3rRelayExec is Keep3rRelayUnitTest {
  modifier happyPath(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) {
    assumeNoPrecompiles(address(_automationVault));
    vm.assume(address(_automationVault) != address(vm));
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.assume(_execData.length > 0 && _execData.length < 30);
    for (uint256 _i; _i < _execData.length; ++_i) {
      vm.assume(_execData[_i].job != address(keep3rV2));
    }

    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller), abi.encode(true));

    vm.startPrank(_relayCaller);
    _;
  }

  function testRevertIfNoExecData(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    _execData = new IAutomationVault.ExecData[](0);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NoExecData.selector);

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testRevertIfCallerIsNotKeeper(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    address _newCaller = makeAddr('newCaller');
    changePrank(_newCaller);

    vm.mockCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _newCaller), abi.encode(false));
    vm.expectRevert(IKeep3rRelay.Keep3rRelay_NotKeeper.selector);

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testRevertIfExecDataContainsKeep3rV2(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    vm.assume(_execData.length > 3);
    _execData[1].job = address(keep3rV2);

    vm.expectRevert(IKeep3rRelay.Keep3rRelay_Keep3rNotAllowed.selector);

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testExpectCallIsKeep3r(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    vm.expectCall(address(keep3rV2), abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller));

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    IAutomationVault.ExecData[] memory _execDataKeep3r = _buildExecDataKeep3r(_execData, _relayCaller);

    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(
        IAutomationVault.exec.selector, _relayCaller, _execDataKeep3r, new IAutomationVault.FeeData[](0)
      )
    );

    keep3rRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    IAutomationVault _automationVault,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _execData) {
    IAutomationVault.ExecData[] memory _execDataKeep3r = _buildExecDataKeep3r(_execData, _relayCaller);

    vm.expectEmit();
    emit AutomationVaultExecuted(_automationVault, _relayCaller, _execDataKeep3r);

    keep3rRelay.exec(_automationVault, _execData);
  }

  function _buildExecDataKeep3r(
    IAutomationVault.ExecData[] memory _execData,
    address _relayCaller
  ) internal view returns (IAutomationVault.ExecData[] memory _execDataKeep3r) {
    uint256 _execDataKeep3rLength = _execData.length + 2;
    _execDataKeep3r = new IAutomationVault.ExecData[](_execDataKeep3rLength);

    _execDataKeep3r[0] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(IKeep3rV2.isKeeper.selector, _relayCaller)
    });

    for (uint256 _i; _i < _execData.length; ++_i) {
      _execDataKeep3r[_i + 1] = _execData[_i];
    }

    _execDataKeep3r[_execData.length + 1] = IAutomationVault.ExecData({
      job: address(keep3rV2),
      jobData: abi.encodeWithSelector(IKeep3rV2.worked.selector, _relayCaller)
    });
  }
}
