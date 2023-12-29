// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

import {AutomationVaultFactory, IAutomationVaultFactory} from '@contracts/AutomationVaultFactory.sol';
import {AutomationVault, IAutomationVault} from '@contracts/AutomationVault.sol';
import {OpenRelay, IOpenRelay} from '@contracts/OpenRelay.sol';
import {GelatoRelay, IGelatoRelay} from '@contracts/GelatoRelay.sol';
import {Keep3rRelay, IKeep3rRelay} from '@contracts/Keep3rRelay.sol';
import {Keep3rBondedRelay, IKeep3rBondedRelay} from '@contracts/Keep3rBondedRelay.sol';
import {XKeeperMetadata, IXKeeperMetadata} from '@contracts/XKeeperMetadata.sol';
import {_ETH} from '@utils/Constants.sol';

abstract contract DeployNativeETH is Script {
  // Deployer EOA
  address public deployer;
  uint256 internal _deployerPk;

  // AutomationVault contracts
  IAutomationVaultFactory public automationVaultFactory;
  IAutomationVault public automationVault;

  // Relay contracts
  IOpenRelay public openRelay;
  IGelatoRelay public gelatoRelay;
  IKeep3rRelay public keep3rRelay;
  IKeep3rBondedRelay public keep3rBondedRelay;

  // Metadata
  IXKeeperMetadata public xKeeperMetadata;

  // AutomationVault params
  address public owner;

  function run() public {
    deployer = vm.rememberKey(_deployerPk);
    vm.startBroadcast(deployer);

    automationVaultFactory = new AutomationVaultFactory();
    automationVault = automationVaultFactory.deployAutomationVault(owner, _ETH, 0);

    openRelay = new OpenRelay();
    gelatoRelay = new GelatoRelay();
    keep3rRelay = new Keep3rRelay();
    keep3rBondedRelay = new Keep3rBondedRelay();

    xKeeperMetadata = new XKeeperMetadata();

    vm.stopBroadcast();
  }
}

contract DeployMainnet is DeployNativeETH {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('MAINNET_DEPLOYER_PK');

    // AutomationVault setup
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }
}

contract DeployGoerli is DeployNativeETH {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('GOERLI_DEPLOYER_PK');

    // AutomationVault setup
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }
}
