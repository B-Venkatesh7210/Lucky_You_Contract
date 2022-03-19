pragma solidity ^0.8.4;
// SPDX-License-Identifier: MIT

//0xDA0bab807633f07f013f94DD0E6A4F96F8742B53

//createGiveaway, giveawayMap, participate, getParticipants, owner are working fine.
//getAllGiveaways(asking for payable), balance and getBalance(both giving diff. values), 

import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";


contract LuckyYou is VRFConsumerBase
{

    address public owner;
    address public contractAddress;
    using Counters for Counters.Counter;
    Counters.Counter private giveawayNumber;

    bytes32 internal keyHash;
    uint256 internal fee;
    address vrfCoordinator = 0x8C7382F9D8f56b33781fE506E897a4F1e2d17255;
    address link = 	0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    uint256 public randomResult; //remove later
    uint public currGiveawayId=0;
    bool public isLocked=false;

    
    
    


    constructor() VRFConsumerBase(vrfCoordinator, link) payable {
        keyHash = 0x6e75b569a01ef56d18cab6a8e71e6600d6ce853834d4a5748b720d06f878b3a4;
        fee = 0.1 * 10 ** 18; 
        
        owner = msg.sender;
        contractAddress = address(this);
        
    }

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }

    function getLinkBalance() public view returns (uint) {
        return LINK.balanceOf(address(this));
    }

    struct Giveaway{
        address creator;
        uint256 uniqueId;
        string message;
        uint256 deadline;
        uint256 timestamp;
        uint amount;
        address[] participants;
        bool isLive;
        address winner;
    }

    mapping (uint256 => Giveaway) public giveawayMap;

    function createGiveaway(string memory _message, uint256 _deadline) public payable {

        //Add a check for block.timestamp to be less than deadline
        require(msg.value>0, "No value given");
        address[] memory empty;
        giveawayNumber.increment();
        
        uint256 newGiveawayNumber = giveawayNumber.current();
        giveawayMap[newGiveawayNumber] = Giveaway(msg.sender, newGiveawayNumber, _message, _deadline, block.timestamp, msg.value, empty, true, address(0));
        
    }

    function participate(uint256 giveawayId) public giveawayExist(giveawayId) payable {
        
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        uint participationFee = currGiveaway.amount/100;
        require(participationFee<=msg.value, "Insufficient fee");
        //Add a check to see if deadline reached and if giveaway has been finished(isLive).
        //Participant should not participate twice.
        currGiveaway.participants.push(payable(msg.sender));
    }

    function getParticipants(uint256 giveawayId) public giveawayExist(giveawayId) view returns (address[] memory) {

        return giveawayMap[giveawayId].participants;

    }

    function endGiveaway(uint256 giveawayId) public giveawayExist(giveawayId) {
        require(isLocked==false, "Please try again later");
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        require(currGiveaway.creator==msg.sender || msg.sender == owner, "tu koi aur hai"); 
        // require(currGiveaway.deadline<=block.timestamp, "Deadline not reached");
        require(currGiveaway.isLive==true, "Giveaway already ended");
        currGiveawayId = giveawayId;
        isLocked=true;
        getRandomNumber();
    }

    modifier giveawayExist(uint256 giveawayId) {
        require(giveawayMap[giveawayId].uniqueId!=0, "Giveaway doesn't exist");
        _;

    }

    modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

     function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness; 
        Giveaway storage currGiveaway = giveawayMap[currGiveawayId];
        uint index = randomness%currGiveaway.participants.length;
        payable(currGiveaway.participants[index]).transfer(currGiveaway.amount);
        giveawayMap[currGiveawayId].isLive=false;
        isLocked=false;
        currGiveawayId=0;
        giveawayMap[currGiveawayId].winner=currGiveaway.participants[index];
        }

  function random(uint256 giveawayId) private view returns (uint) {
      Giveaway storage currGiveaway = giveawayMap[giveawayId];
      return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, currGiveaway.participants)));
  }
  
  function getAllGiveaways() public view returns (Giveaway[] memory) {
        uint totalGiveaways = giveawayNumber.current();
        uint giveawayCount = 0;
        uint currIndex = 0;
        Giveaway[] memory items = new Giveaway[] (giveawayCount);
        for(uint i=0 ; i<totalGiveaways ; i++)
        {
            uint currId = giveawayMap[i+1].uniqueId;
            Giveaway storage currGiveaway = giveawayMap[currId];
            items[currIndex] = currGiveaway;
            currIndex += 1;
        }
        return items;
    }

    //Function changeOwner, unlockContract, 
}

