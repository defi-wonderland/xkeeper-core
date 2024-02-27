// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {CommonIntegrationTest} from '@test/integration/Common.t.sol';

import {IAutomationVault} from '@interfaces/core/IAutomationVault.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {IKeep3rHelper} from '@interfaces/external/IKeep3rHelper.sol';
import {IKeep3rV1} from '@interfaces/external/IKeep3rV1.sol';
import {IKeep3rBondedRelay} from '@interfaces/relays/IKeep3rBondedRelay.sol';
import {_KEEP3R_V2, _KEEP3R_HELPER, _KEEP3R_V1, _KEEP3R_GOVERNOR, _KP3R_WHALE} from './Constants.sol';

contract IntegrationKeep3rRelay is CommonIntegrationTest {
  // Events
  event KeeperValidation(uint256 _gasLeft);
  event KeeperWork(
    address indexed _credit, address indexed _job, address indexed _keeper, uint256 _amount, uint256 _gasLeft
  );

  // Keep3r contracts
  IKeep3rV2 public keep3r;
  IKeep3rHelper public keep3rHelper;
  IKeep3rV1 public kp3r;

  // EOAs
  address public keep3rGovernor;

  function setUp() public override {
    // AutomationVault setup
    CommonIntegrationTest.setUp();

    // Keep3r setup
    keep3rGovernor = _KEEP3R_GOVERNOR;
    keep3r = _KEEP3R_V2;
    keep3rHelper = _KEEP3R_HELPER;
    kp3r = _KEEP3R_V1;

    _addJobAndLiquidity(address(automationVault), 1000 ether);

    // Keep3r callers array
    address[] memory _keepers = new address[](1);
    _keepers[0] = bot;

    // Keep3r selectors array
    bytes4[] memory _keep3rSelectors = new bytes4[](2);
    _keep3rSelectors[0] = keep3r.isKeeper.selector;
    _keep3rSelectors[1] = keep3r.worked.selector;

    // Job selectors array
    bytes4[] memory _jobSelectors = new bytes4[](2);
    _jobSelectors[0] = basicJob.work.selector;
    _jobSelectors[1] = basicJob.workHard.selector;
    IKeep3rBondedRelay.Requirements memory _requirements = IKeep3rBondedRelay.Requirements(address(kp3r), 1 ether, 0, 0);

    // Job data array
    IAutomationVault.JobData[] memory _jobsData = new IAutomationVault.JobData[](2);
    _jobsData[0] = IAutomationVault.JobData(address(keep3r), _keep3rSelectors);
    _jobsData[1] = IAutomationVault.JobData(address(basicJob), _jobSelectors);

    vm.startPrank(owner);

    // Keep3r bonded relay requirements setup
    keep3rBondedRelay.setAutomationVaultRequirements(automationVault, _requirements);

    // AutomationVault approve relay data
    automationVault.addRelay(address(keep3rRelay), _keepers, _jobsData);
    automationVault.addRelay(address(keep3rBondedRelay), _keepers, _jobsData);
  }

  function _addJobAndLiquidity(address _job, uint256 _amount) internal {
    keep3r.addJob(_job);

    vm.prank(keep3rGovernor);
    keep3r.forceLiquidityCreditsToJob(_job, _amount);
  }

  function _bondAndActivateKeeper(address _keeper, uint256 _bondAmount) internal {
    changePrank(_KP3R_WHALE);
    kp3r.transfer(_keeper, _bondAmount);

    vm.startPrank(_keeper);
    kp3r.approve(address(keep3r), _bondAmount);
    keep3r.bond(address(kp3r), _bondAmount);

    skip(keep3r.bondTime() + 1);

    keep3r.activate(address(kp3r));
    changePrank(bot);
  }

  function test_executeJobKeep3r() public {
    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperValidation(0);
    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperWork(address(kp3r), address(automationVault), bot, 0, 0);

    keep3rRelay.exec(automationVault, _execData);
  }

  function test_executeAndGetPaymentFromKeep3r(uint64 _fee, uint8 _howHard) public {
    vm.assume(_howHard > 20);
    vm.assume(_fee > 1 && _fee < 400);
    vm.fee(_fee);

    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, 0);

    // Check that the keeper has no bonded KP3R
    uint256 _payment = keep3r.bonds(bot, address(kp3r));
    assertEq(_payment, 0);

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    // Initializes storage variables
    keep3rRelay.exec(automationVault, _execData);
    _payment = keep3r.bonds(bot, address(kp3r));

    // Execure the job
    uint256 _gasBeforeExec = gasleft();
    keep3rRelay.exec(automationVault, _execData);
    uint256 _gasAfterExec = gasleft();

    uint256 _minBaseFee = keep3rHelper.minBaseFee();

    // If the fee is lower than the base fee, use the base fee
    uint256 _rewardedBaseFee = _minBaseFee > _fee ? _minBaseFee : block.basefee + keep3rHelper.minPriorityFee();

    // Calculate the ETH spent by the keeper
    uint256 _ethSpent = (_gasBeforeExec - _gasAfterExec) * _rewardedBaseFee;

    // Calculate the payment in KP3R and after that quote to ETH
    uint256 _paymentInKP3R = keep3r.bonds(bot, address(kp3r)) - _payment;
    uint256 _oneEthToKp3rQuote = keep3rHelper.quote(1 ether);
    uint256 _paymentInETH = _paymentInKP3R * 1 ether / _oneEthToKp3rQuote;

    // Calculate the profit percentage
    uint256 _profitPercentage = _paymentInETH * 100 / _ethSpent;

    assertApproxEqAbs(_profitPercentage, 110, 5, 'the keeper should earn around 110% of the ETH cost in bonded KP3R');
  }

  function test_executeJobBondedKeep3r() public {
    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, keep3rHelper.targetBond());

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] = IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.work.selector));

    emit KeeperValidation(0);
    vm.expectEmit(address(basicJob));
    emit Worked();
    vm.expectEmit(true, true, true, false, address(keep3r));
    emit KeeperWork(address(kp3r), address(automationVault), bot, 0, 0);

    keep3rBondedRelay.exec(automationVault, _execData);
  }

  function test_executeBondAndGetPaymentFromKeep3r(uint64 _fee, uint8 _howHard) public {
    vm.assume(_howHard > 20);
    vm.assume(_fee > 1 && _fee < 400);
    vm.fee(_fee);

    // Bond and activate keep3r
    _bondAndActivateKeeper(bot, keep3rHelper.targetBond());

    // Check that the keeper has bonded KP3R
    uint256 _payment = keep3r.bonds(bot, address(kp3r));
    assertEq(_payment, keep3rHelper.targetBond());

    IAutomationVault.ExecData[] memory _execData = new IAutomationVault.ExecData[](1);
    _execData[0] =
      IAutomationVault.ExecData(address(basicJob), abi.encodeWithSelector(basicJob.workHard.selector, _howHard));

    // Initializes storage variables
    keep3rBondedRelay.exec(automationVault, _execData);
    _payment = keep3r.bonds(bot, address(kp3r));

    // Execure the job
    uint256 _gasBeforeExec = gasleft();
    keep3rBondedRelay.exec(automationVault, _execData);
    uint256 _gasAfterExec = gasleft();

    uint256 _minBaseFee = keep3rHelper.minBaseFee();

    // If the fee is lower than the base fee, use the base fee
    uint256 _rewardedBaseFee = _minBaseFee > _fee ? _minBaseFee : block.basefee + keep3rHelper.minPriorityFee();

    // Calculate the ETH spent by the keeper
    uint256 _ethSpent = (_gasBeforeExec - _gasAfterExec) * _rewardedBaseFee;

    // Calculate the payment in KP3R and after that quote to ETH
    uint256 _paymentInKP3R = keep3r.bonds(bot, address(kp3r)) - _payment;
    uint256 _oneEthToKp3rQuote = keep3rHelper.quote(1 ether);
    uint256 _paymentInETH = _paymentInKP3R * 1 ether / _oneEthToKp3rQuote;

    // Calculate the profit percentage
    uint256 _profitPercentage = _paymentInETH * 100 / _ethSpent;

    assertApproxEqAbs(_profitPercentage, 120, 5, 'the keeper should earn around 120% of the ETH cost in bonded KP3R');
  }
}
