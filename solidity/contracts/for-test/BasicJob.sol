// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract BasicJob {
  event Worked();

  mapping(uint256 => address) public dataset;
  uint256 public nonce;

  function work() external {
    emit Worked();
  }

  function workHard(uint256 _howHard) external {
    for (uint256 _i; _i < _howHard; ++_i) {
      dataset[nonce++] = address(this);
    }
  }
}
