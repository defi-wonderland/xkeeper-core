// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Script} from 'forge-std/Script.sol';

import {AutomationVaultFactory, IAutomationVaultFactory} from '@contracts/core/AutomationVaultFactory.sol';
import {IAutomationVault} from '@contracts/core/AutomationVault.sol';
import {OpenRelay, IOpenRelay} from '@contracts/relays/OpenRelay.sol';
import {GelatoRelay, IGelatoRelay} from '@contracts/relays/GelatoRelay.sol';
import {Keep3rRelay, IKeep3rRelay} from '@contracts/relays/Keep3rRelay.sol';
import {Keep3rBondedRelay, IKeep3rBondedRelay} from '@contracts/relays/Keep3rBondedRelay.sol';
import {XKeeperMetadata, IXKeeperMetadata} from '@contracts/periphery/XKeeperMetadata.sol';
import {_NATIVE_TOKEN} from '@utils/Constants.sol';
import {IAutomate} from '@interfaces/external/IAutomate.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';

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
  IKeep3rV2 public keep3rV2;

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
    automationVault = automationVaultFactory.deployAutomationVault(owner, _NATIVE_TOKEN, 0);

    // Deploy relays
    gelatoRelay = new GelatoRelay{salt: _salt}(gelatoAutomate);
    openRelay = new OpenRelay{salt: _salt}();
    if (address(keep3rV2) != address(0)) {
      keep3rRelay = new Keep3rRelay{salt: _salt}(keep3rV2);
      keep3rBondedRelay = new Keep3rBondedRelay{salt: _salt}(keep3rV2);
    }

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
    keep3rV2 = IKeep3rV2(0xeb02addCfD8B773A5FFA6B9d1FE99c566f8c44CC);
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
    keep3rV2 = IKeep3rV2(0x12C471f8db6763e83cb20C5A41a91506f744b346);
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
    keep3rV2 = IKeep3rV2(0x745a50320B6eB8FF281f1664Fc6713991661B129);
    vm.createSelectFork(vm.envString('POLYGON_MAINNET_RPC'));
  }
}

contract DeployOptimismMainnet is Deploy {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('DEPLOYER_PK');
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Chain specific setup
    gelatoAutomate = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    keep3rV2 = IKeep3rV2(0x745a50320B6eB8FF281f1664Fc6713991661B129);
    vm.createSelectFork(vm.envString('OPTIMISM_MAINNET_RPC'));
  }
}

contract DeployOptimismSepolia is Deploy {
  function setUp() public {
    // Deployer setup
    _deployerPk = vm.envUint('DEPLOYER_PK');
    owner = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // Chain specific setup
    gelatoAutomate = IAutomate(0x2A6C106ae13B558BB9E2Ec64Bd2f1f7BEFF3A5E0);
    keep3rV2 = IKeep3rV2(0xC3377b30feD174e65778e7E1DaFBb7686082B428);
    vm.createSelectFork(vm.envString('OPTIMISM_SEPOLIA_RPC'));
  }
}
