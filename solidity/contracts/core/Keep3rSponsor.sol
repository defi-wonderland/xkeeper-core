// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import {IKeep3rSponsor} from '@interfaces/core/IKeep3rSponsor.sol';

import {IAutomationVault, IOpenRelay} from '@interfaces/relays/IOpenRelay.sol';
import {_KEEP3R_V2} from '@utils/Constants.sol';

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract Keep3rSponsor is Ownable, IKeep3rSponsor {
  using EnumerableSet for EnumerableSet.AddressSet;

  /// @notice _sponsoredJobs Set of approved job addresses
  EnumerableSet.AddressSet private _sponsoredJobs;
  IOpenRelay public relay;

  constructor(address _relay) Ownable() {
    relay = IOpenRelay(_relay);
  }

  function setRelay(address _relay) external onlyOwner {
    relay = IOpenRelay(_relay);
  }

  function addJobs(address[] calldata _jobs) public onlyOwner {
    for (uint256 _i; _i < _jobs.length;) {
      _sponsoredJobs.add(_jobs[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  function removeJobs(address[] calldata _jobs) public onlyOwner {
    for (uint256 _i; _i < _jobs.length;) {
      _sponsoredJobs.remove(_jobs[_i]);

      unchecked {
        ++_i;
      }
    }
  }

  function exec(IAutomationVault.ExecData[] calldata _execData, IAutomationVault _vault) external {
    if (!_KEEP3R_V2.isKeeper(msg.sender)) revert Keep3rSponsor_NotKeeper();

    for (uint256 _i; _i < _execData.length;) {
      if (!_sponsoredJobs.contains(_execData[_i].job)) revert Keep3rSponsor_NotSponsored();

      unchecked {
        ++_i;
      }
    }

    relay.exec(_vault, _execData, owner());

    _KEEP3R_V2.worked(msg.sender);
  }
}
