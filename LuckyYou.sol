pragma solidity ^0.8.4;
// SPDX-License-Identifier: MIT

//0xDA0bab807633f07f013f94DD0E6A4F96F8742B53

import "@openzeppelin/contracts/utils/Counters.sol";
// import "https://raw.githubusercontent.com/smartcontractkit/chainlink/master/evm-contracts/src/v0.6/VRFConsumerBase.sol";

contract LuckyYou is VRFConsumerBase
{

    address public owner;
    uint256 public balance;
    using Counters for Counters.Counter;
    Counters.Counter private giveawayNumber;
    bytes32 public keyHash;
    uint256 public randomWinner;
    
    


    constructor() VRFConsumerBase(0x6168499c0cFfCaCD319c818142124B7A15E857ab, 0x01BE23585060835E02B77ef475b0Cc51aA1e0709) payable {
        owner = msg.sender;
        balance = msg.value;
        keyHash = 0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;
        fee = 0.1 * 10 ** 18;
        
    }

    receive () payable external {
        balance += msg.value;

    }

    // function getRandomNumber (uint256 userProvidedSeed) public returns (bytes32 requestId) {
    //     return requestRandomness(keyHash, fee, userProvidedSeed);
    // }

    // function fulfillRandomness (bytes32 requestId, uint256 randomness) internal override {
    //     randomWinner = randomWinner.mod(20)+add(1); 
    // }

    function withdraw (uint amount, address payable destAddress) public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(amount<=balance, "Insufficient funds");

        destAddress.transfer(amount);
        balance -= amount;
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
    }

    mapping (uint256 => Giveaway) public giveawayMap;

    function createGiveaway(string memory _message, uint256 _deadline, uint _amount) public payable {

        require(_amount==msg.value, "Jyada chant mat ban");
        address[] memory empty;
        giveawayNumber.increment();
        uint256 newGiveawayNumber = giveawayNumber.current();
        giveawayMap[newGiveawayNumber] = Giveaway(msg.sender, newGiveawayNumber, _message, _deadline, block.timestamp, _amount, empty, true);
        
    }

    function endGiveaway(uint256 giveawayId) public{
        require(giveawayMap[giveawayId].uniqueId!=0, "Giveaway doesn't exist");
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        require(currGiveaway.creator==msg.sender || msg.sender == owner); 
        require(currGiveaway.deadline<=block.timestamp, "Deadline not reached");
        require(currGiveaway.isLive==true, "Giveaway already ended");
        giveawayMap[giveawayId].isLive=false;
    } 

    function participate(uint256 giveawayId) public payable {
        require(giveawayMap[giveawayId].uniqueId!=0, "Giveaway doesn't exist");
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        uint fee = currGiveaway.amount/100;
        require(fee>=msg.value, "Insufficient fee");
        currGiveaway.participants.push(msg.sender);
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
}

