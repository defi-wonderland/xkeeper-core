// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from 'forge-std/Test.sol';

import {GelatoRelay, IAutomationVault, IAutomate, IGelato} from '@contracts/GelatoRelay.sol';

/**
 * @title GelatoRelay Unit tests
 */
contract GelatoRelayUnitTest is Test {
  // Events
  event AutomationVaultExecuted(
    address indexed _automationVault,
    address indexed _relayCaller,
    IAutomationVault.ExecData[] _execData,
    IAutomationVault.FeeData[] _feeData
  );

  // GelatoRelay contract
  GelatoRelay public gelatoRelay;

  // Automate contract
  address public automate;

  // Gelato contract
  address public gelato;

  // Fee collector
  address public feeCollector;

  // Token
  address public token;

  function setUp() public virtual {
    automate = makeAddr('Automate');
    gelato = makeAddr('Gelato');
    feeCollector = makeAddr('FeeCollector');
    token = makeAddr('Token');

    vm.mockCall(automate, abi.encodeWithSelector(IAutomate.gelato.selector), abi.encode(gelato));
    vm.mockCall(gelato, abi.encodeWithSelector(IGelato.feeCollector.selector), abi.encode(feeCollector));

    gelatoRelay = new GelatoRelay(automate);
  }
}

contract UnitGelatoRelayExec is GelatoRelayUnitTest {
  modifier happyPath(address _relayCaller, IAutomationVault _automationVault, uint256 _fee, address _feeToken) {
    assumeNoPrecompiles(address(_automationVault));
    vm.assume(address(_automationVault) != address(vm));
    vm.mockCall(address(_automationVault), abi.encodeWithSelector(IAutomationVault.exec.selector), abi.encode());

    vm.mockCall(automate, abi.encodeWithSelector(IAutomate.getFeeDetails.selector), abi.encode(_fee, _feeToken));

    vm.startPrank(_relayCaller);
    _;
  }

  function testExpectCallWithCorrectsParams(
    address _relayCaller,
    IAutomationVault _automationVault,
    uint256 _fee,
    address _feeToken,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _fee, _feeToken) {
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData({fee: _fee, feeToken: _feeToken, feeRecipient: feeCollector});

    vm.expectCall(
      address(_automationVault),
      abi.encodeWithSelector(IAutomationVault.exec.selector, _relayCaller, _execData, _feeData)
    );

    gelatoRelay.exec(_automationVault, _execData);
  }

  function testEmitJobExecuted(
    address _relayCaller,
    IAutomationVault _automationVault,
    uint256 _fee,
    address _feeToken,
    IAutomationVault.ExecData[] memory _execData
  ) public happyPath(_relayCaller, _automationVault, _fee, _feeToken) {
    IAutomationVault.FeeData[] memory _feeData = new IAutomationVault.FeeData[](1);
    _feeData[0] = IAutomationVault.FeeData({fee: _fee, feeToken: _feeToken, feeRecipient: feeCollector});

    vm.expectEmit();
    emit AutomationVaultExecuted(address(_automationVault), _relayCaller, _execData, _feeData);

    gelatoRelay.exec(_automationVault, _execData);
  }
}
