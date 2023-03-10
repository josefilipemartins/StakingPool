// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.4;

interface INewStakingPool{
    function migration(address _owner, uint256 _tokenId, uint256 _lastUpdate) external;
}