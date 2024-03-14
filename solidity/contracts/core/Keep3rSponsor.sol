pragma solidity 0.8.19;

import {IKeep3rSponsor} from '@interfaces/core/IKeep3rSponsor.sol';

import {IAutomationVault, IOpenRelay} from '@interfaces/relays/IOpenRelay.sol';
import {IKeep3rV2} from '@interfaces/external/IKeep3rV2.sol';
import {_KEEP3R_V2, _ETH} from '@utils/Constants.sol';

import {Ownable} from '@openzeppelin/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/utils/structs/EnumerableSet.sol';

contract Keep3rSponsor is Ownable, IKeep3rSponsor {
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet private _sponsoredJobs;
  IOpenRelay immutable RELAY;

  constructor(address relay) Ownable() {
    RELAY = IOpenRelay(relay);
  }

  modifier validateAndPayKeeper() {
    if (!_KEEP3R_V2.isKeeper(msg.sender)) revert KeeperNotValid();
    _;
    // @note payment amount is questionable
    _KEEP3R_V2.worked(msg.sender);
  }

  // @note unsure if jobs should also be added to automation vault or if assumed to already be in approvedJobs list
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

  function exec(IAutomationVault.ExecData[] calldata _execData, IAutomationVault _vault) external validateAndPayKeeper {
    // @note if _execData holds data for just 1 job, this is unnecessary
    for (uint256 _i; _i < _execData.length;) {
      if (!_sponsoredJobs.contains(_execData[_i].job)) revert JobNotSponsored();

      unchecked {
        ++_i;
      }
    }

    RELAY.exec(_vault, _execData, msg.sender);

    for (uint256 _i; _i < _execData.length;) {
      emit JobExecuted(_execData[_i].job);

      unchecked {
        ++_i;
      }
    }
  }
}
