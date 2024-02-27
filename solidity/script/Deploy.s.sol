// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

import {AutomationVaultFactory, IAutomationVaultFactory} from '@contracts/core/AutomationVaultFactory.sol';
import {AutomationVault, IAutomationVault} from '@contracts/core/AutomationVault.sol';
import {OpenRelay, IOpenRelay} from '@contracts/relays/OpenRelay.sol';
import {GelatoRelay, IGelatoRelay} from '@contracts/relays/GelatoRelay.sol';
import {Keep3rRelay, IKeep3rRelay} from '@contracts/relays/Keep3rRelay.sol';
import {Keep3rBondedRelay, IKeep3rBondedRelay} from '@contracts/relays/Keep3rBondedRelay.sol';
import {XKeeperMetadata, IXKeeperMetadata} from '@contracts/periphery/XKeeperMetadata.sol';
import {_ETH, _AUTOMATE} from '@utils/Constants.sol';
import {BasicJobChecker} from '@contracts/for-test/BasicJobChecker.sol';
import {IAutomate} from '@interfaces/external/IAutomate.sol';

abstract contract Deploy is Script {
  // When new contracts need to be deployed, make sure to update the salt version to avoid address collition
  string public constant SALT = 'v1.0';

  // Deployer EOA
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

  // External contracts
  IAutomate public gelatoAutomate;

  // AutomationVault params
  address public owner;

  function run() public {
    // Deployer EOA
    address _deployer = vm.rememberKey(_deployerPk);
    bytes32 _salt = keccak256(abi.encodePacked(SALT, msg.sender));

    vm.startBroadcast(_deployer);

    // Deploy automation vault factory
    automationVaultFactory = new AutomationVaultFactory{salt: _salt}();

    // Deploy a sample automation vault for verification purposes
    automationVault = automationVaultFactory.deployAutomationVault(owner, _ETH, 0);

    // Deploy relays
    gelatoRelay = new GelatoRelay{salt: _salt}(gelatoAutomate);
    openRelay = new OpenRelay{salt: _salt}();
    keep3rRelay = new Keep3rRelay{salt: _salt}();
    keep3rBondedRelay = new Keep3rBondedRelay{salt: _salt}();

    // Deploy metadata contract
    xKeeperMetadata = new XKeeperMetadata{salt: _salt}();

    vm.stopBroadcast();
  }
}

struct PredeploymentData {
  string rpc;
  IAutomate gelatoAutomate;
}

contract DeployEthereumMainnet is Deploy {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('DEPLOYER_PK');
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Chain specific setup
    gelatoAutomate = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    vm.createSelectFork(vm.envString('ETHEREUM_MAINNET_RPC'));
  }
}

contract DeployEthereumSepolia is Deploy {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('DEPLOYER_PK');
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Chain specific setup
    gelatoAutomate = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    vm.createSelectFork(vm.envString('ETHEREUM_SEPOLIA_RPC'));
  }
}

contract DeployPolygonMainnet is Deploy {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('DEPLOYER_PK');
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Chain specific setup
    gelatoAutomate = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    vm.createSelectFork(vm.envString('POLYGON_MAINNET_RPC'));
  }
}
