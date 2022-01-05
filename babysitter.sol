// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

// Interface for our erc20 token
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address tokenOwner)
        external
        view
        returns (uint256 balance);
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
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}
interface ICudlFinance {
  function MUSE_DAO (  ) external view returns ( address );
  function MUSE_DEVS (  ) external view returns ( address );
  function OPERATOR_ROLE (  ) external view returns ( bytes32 );
  function addOperator ( address _address, bool _isAllowed ) external;
  function addScore ( uint256 petId, uint256 amount ) external;
  function addTOD ( uint256 petId, uint256 duration ) external;
  function burnScore ( uint256 petId, uint256 amount ) external;
  function burnTod ( uint256 petId, uint256 duration ) external;
  function buyAccesory ( uint256 nftId, uint256 itemId ) external;
  function careTaker ( uint256, address ) external view returns ( address );
  function changeEarners ( address _newAddress, address _dao ) external;
  function changeToken ( address newToken ) external;
  function claimEarnings (  ) external;
  function claimMiningRewards ( uint256 nftId ) external;
  function claimMultiple ( uint256[] calldata ids ) external;
  function createItem ( string calldata name, uint256 price, uint256 points, uint256 timeExtension ) external;
  function cudlPets (  ) external view returns ( address );
  function editCurves ( uint256 _la, uint256 _lb, uint256 _ra, uint256 _rb ) external;
  function editItem ( uint256 _id, uint256 _price, uint256 _points, string calldata _name, uint256 _timeExtension ) external;
  function fatality ( uint256 _deadId, uint256 _tokenId ) external;
  function feedMultiple ( uint256[] calldata ids, uint256[] calldata itemIds ) external;
  function feesEarned (  ) external view returns ( uint256 );
  function getCareTaker ( uint256 _tokenId, address _owner ) external view returns ( address );
  function getPetInfo ( uint256 _nftId ) external view returns ( uint256 _pet, bool _isStarving, uint256 _score, uint256 _level, uint256 _expectedReward, uint256 _timeUntilStarving, uint256 _lastTimeMined, uint256 _timepetBorn, address _owner, address _token, uint256 _tokenId, bool _isAlive );
  function getRewards ( uint256 tokenId ) external view returns ( uint256 );
  function giveLife ( address nft, uint256 _id ) external;
  function giveLifePrice (  ) external view returns ( uint256 );
  function isNftInTheGame ( address, uint256 ) external view returns ( bool );
  function isOperator ( address ) external view returns ( bool );
  function isPetSafe ( uint256 _nftId ) external view returns ( bool );
  function itemName ( uint256 ) external view returns ( string memory );
  function itemPoints ( uint256 ) external view returns ( uint256 );
  function itemPrice ( uint256 ) external view returns ( uint256 );
  function itemTimeExtension ( uint256 ) external view returns ( uint256 );
  function la (  ) external view returns ( uint256 );
  function lastBonker (  ) external view returns ( address );
  function lastTimeMined ( uint256 ) external view returns ( uint256 );
  function lb (  ) external view returns ( uint256 );
  function level ( uint256 tokenId ) external view returns ( uint256 );
  function nftToId ( address, uint256 ) external view returns ( uint256 );
  function onERC721Received ( address, address, uint256, bytes calldata ) external returns ( bytes4 );
  function owner (  ) external view returns ( address );
  function petDead ( uint256 ) external view returns ( bool );
  function petDetails ( uint256 ) external view returns ( address nft, uint256 id );
  function petScore ( uint256 ) external view returns ( uint256 );
  function ra (  ) external view returns ( uint256 );
  function rb (  ) external view returns ( uint256 );
  function renounceOwnership (  ) external;
  function setCareTaker ( uint256 _tokenId, address _careTaker, bool clearCareTaker ) external;
  function setGiveLifePrice ( uint256 _price ) external;
  function setPets ( address _pets ) external;
  function setSupported ( address _nft, bool isSupported ) external;
  function supportedNfts ( address ) external view returns ( bool );
  function timePetBorn ( uint256 ) external view returns ( uint256 );
  function timeUntilStarving ( uint256 ) external view returns ( uint256 );
  function token (  ) external view returns ( address );
  function transferOwnership ( address newOwner ) external;
}

contract BabySitter {
    address public owner;
    uint256 public percentage = 2000;
    mapping (address => uint) public pendingRewards;
    IERC20 Cudl = IERC20(0x72C546FFABa89b269C4290698D8f106f05e090Fe);
    ICudlFinance CudlFinance = ICudlFinance(0x58b1422b21d58Ae6073ba7B28feE62F704Fc2539);
    constructor() {
        owner = msg.sender;
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
        Cudl.approve(0x58b1422b21d58Ae6073ba7B28feE62F704Fc2539, price);
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
