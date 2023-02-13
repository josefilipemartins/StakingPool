// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.4;

import "./Ownable.sol";
import "./IERC721Receiver.sol";
import "./MainNFT.sol";
import "./TOKEN.sol";
import "./INewStakingPool.sol";

contract NewStakingPool is IERC721Receiver,Ownable{

    struct stakedInfo{
        address owner;
        uint256 tokenId;
        uint256 lastUpdate;
        bool exists;
    }
    
    event tokenStaked(address indexed _owner, uint256 indexed _tokenId, uint256 indexed _lastUpdate);
    event claimedTokens(uint256 indexed _tokenId, uint256 _tokensEarned, bool indexed _unstake, address indexed _owner);

    uint256 constant public TOKEN_RATE = 3 ether;
    uint256 public totalNftStaked;

    mapping(uint256 => stakedInfo) stakingPool;

    address migrator;

    bool public staking = false;

    MainNFT mainNFT;
    TOKEN token;

    constructor (
        address _migratorAddress
    ){
        migrator = _migratorAddress;
    }

    modifier onlyMigrator{
        require(migrator == msg.sender, "NewFirepit: Caller is not the Migrator");
        _;
    }

    function stakingTokens(uint256[] calldata _tokenIds) external{
        require(staking,"Staking not available yet");
        for (uint i = 0; i < _tokenIds.length; i++) {
            require (!stakingPool[_tokenIds[i]].exists, 'Already in stake');
            require(msg.sender == mainNFT.ownerOf(_tokenIds[i]),"Not the owner of this token");
            mainNFT.transferFrom(msg.sender, address(this),_tokenIds[i]);
            uint256 timestamp = uint80(block.timestamp);
            stakingPool[_tokenIds[i]] = stakedInfo({
                owner: _msgSender(),
                tokenId: _tokenIds[i],
                lastUpdate: timestamp,
                exists: true
            });
            totalNftStaked += 1;
            emit tokenStaked(_msgSender(), _tokenIds[i], timestamp);
        } 
    }

    function clamingTokens(uint256[] calldata _tokenIds, bool[] calldata _unstake) external{
        require(_tokenIds.length == _unstake.length,"Params must have same lenght");
        uint256 reward = 0;
        for (uint i = 0; i < _tokenIds.length; i++) {
            require(stakingPool[_tokenIds[i]].exists,"Not in stake");
            require(stakingPool[_tokenIds[i]].owner == msg.sender, "Not the user which has staked this token");
            reward += TOKEN_RATE * (block.timestamp - stakingPool[_tokenIds[i]].lastUpdate) / 1 days;
            if(_unstake[i]){
                mainNFT.safeTransferFrom(address(this), msg.sender, _tokenIds[i], ""); // Send back the NFT
                delete stakingPool[_tokenIds[i]];
                totalNftStaked -= 1;
            }
            else{
                stakingPool[_tokenIds[i]].lastUpdate = uint80(block.timestamp);    
            }
            emit claimedTokens(_tokenIds[i], reward, _unstake[i], msg.sender);
        }
        token.mint(msg.sender, reward);
    }

    function emergencyMigration(address _newContract) external onlyOwner{
        INewStakingPool contractToMigrate = INewStakingPool(_newContract); 
        for (uint i = 0; i < totalNftStaked; i++) {
            mainNFT.safeTransferFrom(address(this), _newContract, stakingPool[i].tokenId, ""); // Send back the NFT
            contractToMigrate.migration(stakingPool[i].owner, stakingPool[i].tokenId, stakingPool[i].lastUpdate);
            totalNftStaked -= 1;
        }
    }

    function migration(address _owner, uint256 _tokenId, uint256 _lastUpdate) external onlyMigrator{
        stakingPool[totalNftStaked] = stakedInfo({
                owner: _owner,
                tokenId: _tokenId,
                lastUpdate: _lastUpdate,
                exists: true
        });
        totalNftStaked += 1;
    }

    function setDependencies(address _token, address _nft) external onlyOwner{
        token = TOKEN(_token);
        mainNFT = MainNFT(_nft);
    }

    function calculateReward(uint256[] calldata _tokenIds) external view returns (uint256){
        uint256 total =0;
        for (uint i = 0; i < _tokenIds.length; i++) {
            require(stakingPool[_tokenIds[i]].exists,"Not in stake");
            total += (TOKEN_RATE * (block.timestamp - stakingPool[_tokenIds[i]].lastUpdate) / 1 days);
        }
        return total;
    }

    function viewStakingPool (uint256 _tokenId) external view returns (stakedInfo memory){
        return stakingPool[_tokenId];
    }

    function isOwnerOfStakedTokens(uint256[] calldata _tokenIds, address _owner) external view returns (bool){
        for(uint i =0; i <_tokenIds.length; i++){
            if(stakingPool[_tokenIds[i]].owner != _owner){
                return false;
            }
        }
        return true;
    }

    function setStaking(bool _state) external onlyOwner {
		staking = _state;
	}

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        if(from != migrator){
            require(from == address(0x0), "Must use staking function to send tokens to the stakingPool");
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}