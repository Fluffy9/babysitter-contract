// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// Interface for our erc20 token
interface IERC20 {
    function allowance(address tokenOwner, address spender)
        external
        view
        returns (uint256 remaining);
    function transfer(address to, uint256 tokens)
        external
        returns (bool success);
    function approve(address spender, uint256 tokens)
        external
        returns (bool success);
    function transferFrom(
        address from,
        address to,
        uint256 tokens
    ) external returns (bool success);
}
interface ICudlFinance {
  function buyAccesory ( uint256 nftId, uint256 itemId ) external;
  function claimMiningRewards ( uint256 nftId ) external;
  function getPetInfo ( uint256 _nftId ) external view returns ( uint256 _pet, bool _isStarving, uint256 _score, uint256 _level, uint256 _expectedReward, uint256 _timeUntilStarving, uint256 _lastTimeMined, uint256 _timepetBorn, address _owner, address _token, uint256 _tokenId, bool _isAlive );
  function getRewards ( uint256 tokenId ) external view returns ( uint256 );
  function itemPrice ( uint256 ) external view returns ( uint256 );
}

contract BabySitter {
    address public owner;
    uint256 public percentage = 2000;
    mapping (address => uint) public pendingRewards;
    IERC20 Cudl = IERC20(0x72C546FFABa89b269C4290698D8f106f05e090Fe);
    ICudlFinance CudlFinance = ICudlFinance(0x58b1422b21d58Ae6073ba7B28feE62F704Fc2539);
    constructor() {
        owner = msg.sender;
        Cudl.approve(0x58b1422b21d58Ae6073ba7B28feE62F704Fc2539, type(uint256).max);

    }
    modifier onlyOwner(){
        require(msg.sender == owner);
        _;
    }
    // Only current owner can set a new owner to the contract. 
    function newOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    // Sets the owner's cut of cudl rewards in basis points.
    // Only owner can set 
    // Owners cut goes towards gas costs, server costs, and profits
    function newPercentage(uint256 _percentage) public onlyOwner {
        percentage = _percentage;
    }
    // Internal function to claim cudl
    function Claim(uint256 id) internal returns(uint256){
        CudlFinance.claimMiningRewards(id);
        return CudlFinance.getRewards(id);
    }
    // Determines whether or not we can feed the pet a particular type of food (or at all)
    // Pet must be alive
    // Pet must have a reward amount greater than the food price OR an allowance from the parent that covers the difference
    function CanFeed(uint256 id, uint256 food) view public returns(bool){
        (, , , , , , , , address _parent, , , bool _isAlive) = CudlFinance.getPetInfo(id);
        //pet must be alive
        if(!_isAlive){ return false; }
        uint256 reward = CudlFinance.getRewards(id);
        //rewards must be greater than food price, or the owner is funding it
        uint256 price = CudlFinance.itemPrice(food);
        if(reward > price) {
            return true;
        }
        uint256 allowance = Cudl.allowance(_parent, address(this));
        if(allowance + reward > price){
            return true;
        }
        return false;

    }
    // Feeds and claims cudl from multiple pets
    function FeedMultiple(uint256[] calldata ids, uint256[] calldata food) external {
        for(uint256 i = 0; i < ids.length; i++){
            Feed(ids[i], food[i]);
        }
    }
    // Feeds and claims a singe pet for internal use
    function Feed(uint256 id, uint256 food) internal {
        require(CanFeed(id, food));
        uint256 reward = Claim(id);
        uint256 price = CudlFinance.itemPrice(food);
        (, , , , , , , , address _parent, , ,) = CudlFinance.getPetInfo(id);
        if(reward > price){
            CudlFinance.buyAccesory(id,food);
            Distribute(_parent, reward-price);
            return;
        }
        Cudl.transferFrom(_parent, address(this), price-reward);
        CudlFinance.buyAccesory(id,food);
    }
    // Distributes the cudl reward among parties to claim later
    function Distribute(address _parent, uint256 reward) private {
        //Keep 20%
        uint256 shareForX = reward * percentage / 10000;
        pendingRewards[_parent] += reward-shareForX;
        pendingRewards[address(this)] += shareForX;
    }
    // Allows the parent to claim their accumulated share of cudl
    function Claim(address _parent) external {
        require(_parent != address(this));
        uint256 amount = pendingRewards[_parent];
        pendingRewards[_parent] = 0;
        Cudl.transfer(_parent, amount);
    }
    // Allows the owner to claim their accumulated share of cudl
    function OwnerClaim() onlyOwner external {
        uint256 amount = pendingRewards[address(this)];
        pendingRewards[address(this)] = 0;
        Cudl.transfer(owner, amount);
    }   
}
