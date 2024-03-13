// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IAutomate, LibDataTypes} from '@interfaces/external/IAutomate.sol';
import {IGelato} from '@interfaces/external/IGelato.sol';
import {IOpsProxyFactory} from '@interfaces/external/IOpsProxyFactory.sol';
import {_NATIVE_TOKEN, _OPS_PROXY_FACTORY} from './Constants.sol';

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
    // AutomationVault setup
    CommonIntegrationTest.setUp();

    // Gelato setup
    automate = gelatoRelay.AUTOMATE();
    gelato = IGelato(automate.gelato());

    opsProxyFactory = _OPS_PROXY_FACTORY;

    taskId = _createTask(owner);

    // Whitelisted callers array
    address[] memory _whitelistedCallers = new address[](1);
    _whitelistedCallers[0] = _getDedicatedMsgSender(owner);

    // Job selectors array
    bytes4[] memory _jobSelectors = new bytes4[](1);
    _jobSelectors[0] = basicJob.work.selector;

    // Job data array
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](1);
    _jobsData[0] = IAutomationVault.JobData(address(basicJob), _jobSelectors);

    startHoax(owner);

    // AutomationVault approve relay data
    automationVault.addRelay(address(gelatoRelay), _whitelistedCallers, _jobsData);

    address(automationVault).call{value: 100 ether}('');

    changePrank(address(gelato));
  }

  /**
   * @notice Helper function used for create a module data for Gelato
   */
  function _createModuleData() internal pure returns (LibDataTypes.ModuleData memory _moduleData) {
    _moduleData.modules = new LibDataTypes.Module[](1);
    _moduleData.args = new bytes[](1);
    _moduleData.modules[0] = LibDataTypes.Module.PROXY;
    _moduleData.args[0] = bytes('');
  }

  /**
   * @notice Helper function used for create a task in Gelato
   */
  function _createTask(address _taskCreator) internal returns (bytes32 _taskId) {
    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    vm.prank(_taskCreator);
    _taskId = automate.createTask(
      address(gelatoRelay), abi.encodeWithSelector(gelatoRelay.exec.selector), _moduleData, _NATIVE_TOKEN
    );
  }

  function _getDedicatedMsgSender(address _account) internal view returns (address _dedicatedMsgSender) {
    (_dedicatedMsgSender,) = opsProxyFactory.getProxyOf(_account);
  }

  function test_executeJobGelato() public {
    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    // Create exec data for Automate
    bytes memory _execDataAutomate = abi.encodeWithSelector(gelatoRelay.exec.selector, automationVault, _execData);

    // Create module data for Automate
    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(address(automate));
    emit ExecSuccess(1 ether, _NATIVE_TOKEN, address(gelatoRelay), _execDataAutomate, taskId, true);

    // Execute in Automate and expect Gelato to execute the job
    automate.exec(owner, address(gelatoRelay), _execDataAutomate, _moduleData, 1 ether, _NATIVE_TOKEN, true);
  }

  function test_executeAndGetPaymentFromGelato() public {
    // Get the fee collector balance
    address _feeCollector = gelato.feeCollector();
    uint256 _balance = _feeCollector.balance;

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    // Create exec data for Automate
    bytes memory _execDataAutomate = abi.encodeWithSelector(gelatoRelay.exec.selector, automationVault, _execData);

    // Create module data for Automate
    LibDataTypes.ModuleData memory _moduleData = _createModuleData();

    // Execute in Automate and expect Gelato to execute the job
    automate.exec(owner, address(gelatoRelay), _execDataAutomate, _moduleData, 1 ether, _NATIVE_TOKEN, true);

    assertEq(_feeCollector.balance, _balance + 1 ether);
  }
}
