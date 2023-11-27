// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IAutomate, LibDataTypes} from '@interfaces/external/IAutomate.sol';
import {IGelato} from '@interfaces/external/IGelato.sol';
import {IOpsProxyFactory} from '@interfaces/external/IOpsProxyFactory.sol';
import {_ETH, _AUTOMATE, _OPS_PROXY_FACTORY} from '@utils/Constants.sol';

contract IntegrationGelatoRelay is CommonIntegrationTest {
  // Events
  event ExecSuccess(
    uint256 indexed _txFee,
    address indexed _feeToken,
    address indexed _execAddress,
    bytes _execData,
    bytes32 _taskId,
    bool _callSuccess
  );

  // Gelato contracts
  IAutomate public automate;
  IGelato public gelato;
  IOpsProxyFactory public opsProxyFactory;

  // Gelato task
  bytes32 public taskId;

  function setUp() public override {
    CommonIntegrationTest.setUp();

    // Gelato setup
    automate = _AUTOMATE;
    gelato = IGelato(automate.gelato());
    opsProxyFactory = _OPS_PROXY_FACTORY;

    taskId = _createTask(owner);

    // AutomationVault setup
    address[] memory _whitelistedCallers = new address[](1);
    _whitelistedCallers[0] = _getDedicatedMsgSender(owner);
    bytes4[] memory _jobSelectors = new bytes4[](2);
    _jobSelectors[0] = basicJob.work.selector;
    _jobSelectors[1] = basicJob.workHard.selector;

    startHoax(owner);
    automationVault.approveRelayCallers(address(gelatoRelay), _whitelistedCallers);
    automationVault.approveJobSelectors(address(basicJob), _jobSelectors);
    address(automationVault).call{value: 100 ether}('');

    changePrank(address(gelato));
  }

  function _createModuleData() internal pure returns (LibDataTypes.ModuleData memory _moduleData) {
    _moduleData.modules = new LibDataTypes.Module[](1);
    _moduleData.args = new bytes[](1);
    _moduleData.modules[0] = LibDataTypes.Module.PROXY;
    _moduleData.args[0] = bytes('');
  }

  function _createTask(address _taskCreator) internal returns (bytes32 _taskId) {
    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    vm.prank(_taskCreator);
    _taskId =
      automate.createTask(address(gelatoRelay), abi.encodeWithSelector(gelatoRelay.exec.selector), _moduleData, _ETH);
  }

  function _getDedicatedMsgSender(address _account) internal view returns (address _dedicatedMsgSender) {
    (_dedicatedMsgSender,) = opsProxyFactory.getProxyOf(_account);
  }

  function test_executeJobGelato() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(bot, _ETH, 1 ether);

    bytes memory _execDataAutomate =
      abi.encodeWithSelector(gelatoRelay.exec.selector, automationVault, _execData, _feeData);

    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(address(automate));
    emit ExecSuccess(1 ether, _ETH, address(gelatoRelay), _execDataAutomate, taskId, true);

    automate.exec(owner, address(gelatoRelay), _execDataAutomate, _moduleData, 1 ether, _ETH, false, true);
  }

  function test_executeAndGetPaymentFromGelato(uint16 _howHard) public {
    vm.assume(_howHard <= 1000);

    assertEq(bot.balance, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData(bot, _ETH, 1 ether);

    bytes memory _execDataAutomate =
      abi.encodeWithSelector(gelatoRelay.exec.selector, automationVault, _execData, _feeData);

    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    automate.exec(owner, address(gelatoRelay), _execDataAutomate, _moduleData, 1 ether, _ETH, false, true);

    assertEq(bot.balance, 1 ether);
  }
}
