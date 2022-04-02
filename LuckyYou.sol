pragma solidity ^0.8.4;
// SPDX-License-Identifier: MIT

//0xDA0bab807633f07f013f94DD0E6A4F96F8742B53

//createGiveaway, giveawayMap, participate, getParticipants, owner are working fine.
//getAllGiveaways(asking for payable), balance and getBalance(both giving diff. values), 

import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


abstract contract OpsReady {
    address public immutable ops;
    address payable public immutable gelato;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    constructor(address _ops) {
        ops = _ops;
        gelato = IOps(_ops).gelato();
    }

    function _transfer(uint256 _amount) internal {
        (bool success, ) = gelato.call{value: _amount}("");
        require(success, "_transfer: ETH transfer failed");
    }
}

interface IOps {
  function createTaskNoPrepayment(
      address _execAddress,
      bytes4 _execSelector,
      address _resolverAddress,
      bytes calldata _resolverData,
      address _feeToken
  ) external returns (bytes32 task);

  function gelato() external view returns (address payable);

  function getFeeDetails() external view returns (uint256, address) ;
}


contract LuckyYou is VRFConsumerBase, OpsReady
{

    address public owner;
    using Counters for Counters.Counter;
    Counters.Counter private giveawayNumber;

    bytes32 internal keyHash;
    uint256 internal fee;
    address vrfCoordinator = 0x3d2341ADb2D31f1c5530cDC622016af293177AE0;
    address link = 	0xb0897686c545045aFc77CF20eC7A532E3120E0F1;
    address opsAddress = 0x527a819db1eb0e34426297b03bae11F2f8B3A19E; 
    uint public currGiveawayId=0;
    bool public isLocked=false;

    
    
    


    constructor() VRFConsumerBase(vrfCoordinator, link) OpsReady(opsAddress) payable {
        keyHash = 0xf86195cf7690c55907b2b611ebb7343a6f649bff128701cc542f0569e2c549da;
        fee = 0.1 * 10 ** 15;
        owner = msg.sender;
        }

    event GiveawayCreated(
        address creator,
        uint256 uniqueId,
        string message,
        string socialLink,
        uint256 deadline,
        uint256 timestamp,
        uint amount,
        uint participationFee,
        address[] participants,
        bool isLive,
        address winner,
        bytes32 taskId,
        bool isProcessing
    );

    event GiveawayParticipated(
        address creator,
        uint256 uniqueId,
        bool isLive,
        uint amount,
        uint participationFee,
        address[] participants
    );

    event GiveawayEnded(
        address creator,
        uint256 uniqueId,
        bool isLive,
        uint amount,
        uint participationFee,
        address winner
    );

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
        string socialLink;
        uint256 deadline;
        uint256 timestamp;
        uint amount;
        uint participationFee;
        address[] participants;
        bool isLive;
        address winner;
        bytes32 taskId;
        bool isProcessing;
    }

    mapping (uint256 => Giveaway) public giveawayMap;

    function createGiveaway(string memory _message, string memory _socialLink, uint256 _deadline) public payable {

        require(block.timestamp<_deadline, "Enter valid time");
        require(msg.value>0, "No value given");
        uint _participationFee = msg.value/100;
        address[] memory empty;
        giveawayNumber.increment();
        uint256 newGiveawayNumber = giveawayNumber.current();
        bytes32 tempTaskId=IOps(ops).createTaskNoPrepayment(
            address(this), 
            this.endGiveaway.selector,
            address(this),
            abi.encodeWithSelector(this.checker.selector, newGiveawayNumber),
            ETH
        );
        giveawayMap[newGiveawayNumber] = Giveaway(msg.sender, newGiveawayNumber, _message, _socialLink, _deadline, block.timestamp, msg.value, _participationFee, empty, true, address(0), tempTaskId, false);
        emit GiveawayCreated(msg.sender, newGiveawayNumber, _message, _socialLink, _deadline, block.timestamp, msg.value, _participationFee, empty, true, address(0), tempTaskId, false);
    }

    function participate(uint256 giveawayId) public giveawayExist(giveawayId) payable {
        
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        require(currGiveaway.isLive==true, "Giveaway has been finished");
        require(currGiveaway.deadline>=block.timestamp, "Giveaway time is over");
        for(uint i=0 ; i<currGiveaway.participants.length ; i++)
        {
            require(currGiveaway.participants[i]!=msg.sender, "You cannot participate twice");
        }
        require(currGiveaway.participationFee<=msg.value, "Insufficient fee");
        currGiveaway.participants.push(payable(msg.sender));
        emit GiveawayParticipated(currGiveaway.creator, currGiveaway.uniqueId, currGiveaway.isLive, currGiveaway.amount, currGiveaway.participationFee, currGiveaway.participants);
    }

    function getParticipants(uint256 giveawayId) public giveawayExist(giveawayId) view returns (address[] memory) {
        return giveawayMap[giveawayId].participants;
        }

    function endGiveaway(uint256 giveawayId) public giveawayExist(giveawayId) {
        require(isLocked==false, "Please try again later");
        Giveaway storage currGiveaway = giveawayMap[giveawayId];
        require(currGiveaway.creator==msg.sender || msg.sender == owner || msg.sender == opsAddress, "tu koi aur hai"); 
        require(currGiveaway.deadline<=block.timestamp, "Deadline not reached");
        require(currGiveaway.isLive==true, "Giveaway already ended");
        giveawayMap[giveawayId].isProcessing = true;
        
        

        uint256 fees;
        address feeToken;
        (fees, feeToken) = IOps(ops).getFeeDetails();
        _transfer(fees);
        
        currGiveawayId = giveawayId;
        isLocked=true;
        getRandomNumber();
        emit GiveawayEnded(currGiveaway.creator, currGiveaway.uniqueId, currGiveaway.isLive, currGiveaway.amount, currGiveaway.participationFee, currGiveaway.winner);
    }

    modifier giveawayExist(uint256 giveawayId) {
        require(giveawayMap[giveawayId].uniqueId!=0, "Giveaway doesn't exist");
        _;

    }

    modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

     function getRandomNumber() internal returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        Giveaway storage currGiveaway = giveawayMap[currGiveawayId];
        if(currGiveaway.participants.length==0)
        {
            payable(currGiveaway.creator).transfer(currGiveaway.amount);
        }
        else {
            uint index = randomness%currGiveaway.participants.length;
            payable(currGiveaway.participants[index]).transfer(currGiveaway.amount);
            giveawayMap[currGiveawayId].winner=currGiveaway.participants[index];
        }
        
        giveawayMap[currGiveawayId].isProcessing=false;
        giveawayMap[currGiveawayId].isLive=false;
        isLocked=false;
        currGiveawayId=0;
        }

  
  function getAllGiveaways() public view returns (Giveaway[] memory) {
        uint totalGiveaways = giveawayNumber.current();
        uint currIndex = 0;
        Giveaway[] memory allGiveaways = new Giveaway[] (totalGiveaways);
        for(uint i=0 ; i<totalGiveaways ; i++)
        {
            uint currId = giveawayMap[i+1].uniqueId;
            Giveaway storage currGiveaway = giveawayMap[currId];
            allGiveaways[currIndex] = currGiveaway;
            currIndex += 1;
        }
        return allGiveaways;
    }

   function getParticipatedGiveaways() public view returns (Giveaway[] memory) {
       uint totalGiveaways = giveawayNumber.current();
       uint currIndex = 0;
       uint participatedGiveawaysLength = 0;
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
        for(uint j=0 ; j<currGiveaway.participants.length ; j++)
        {
            if(currGiveaway.participants[j]==msg.sender)
           {
               participatedGiveawaysLength++;

           }

        }
       }
       Giveaway[] memory participatedGiveaways = new Giveaway[] (participatedGiveawaysLength);
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
        for(uint j=0 ; j<currGiveaway.participants.length ; j++)
        {
            if(currGiveaway.participants[j]==msg.sender)
           {
               participatedGiveaways[currIndex] = currGiveaway;
               currIndex +=1;
           }

        }
       }
       return participatedGiveaways;
   }

   function getWonGiveaways() public view returns (Giveaway[] memory) {
       uint totalGiveaways = giveawayNumber.current();
       uint currIndex = 0;
       uint wonGiveawaysLength = 0;
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
           if(currGiveaway.winner==msg.sender && currGiveaway.isLive==false)
           {
               wonGiveawaysLength++;
           }
       }
       Giveaway[] memory wonGiveaways = new Giveaway[] (wonGiveawaysLength);
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
           if(currGiveaway.winner==msg.sender && currGiveaway.isLive==false)
           {
               wonGiveaways[currIndex] = currGiveaway;
               currIndex +=1;
           }
       }

       return wonGiveaways;

   }

   function getYourGiveaways() public view returns (Giveaway[] memory) {
       uint totalGiveaways = giveawayNumber.current();
       uint currIndex = 0;
       uint yourGiveawaysLength = 0;
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
           if(currGiveaway.creator==msg.sender)
           {
               yourGiveawaysLength++;
           }
       }
       Giveaway[] memory yourGiveaways = new Giveaway[] (yourGiveawaysLength);
       for(uint i=0 ; i<totalGiveaways ; i++)
       {
           uint currId = giveawayMap[i+1].uniqueId;
           Giveaway storage currGiveaway = giveawayMap[currId];
           if(currGiveaway.creator==msg.sender)
           {
               yourGiveaways[currIndex] = currGiveaway;
               currIndex +=1;
           }
       }

       return yourGiveaways;

   }



   function getTimestamp() public view returns (uint256 time){
        time = block.timestamp;
    }

    function rechargeEth() public payable{}

    function checker(uint256 giveawayId)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        canExec = block.timestamp >= giveawayMap[giveawayId].deadline && giveawayMap[giveawayId].isLive;

        execPayload = abi.encodeWithSelector(
            this.endGiveaway.selector,
            giveawayId
        );
    }


    function changeOwner(address newAddress) public onlyOwner returns (address) {
        owner = newAddress;
        return owner;
    }

    function unlockContract() public onlyOwner {
        isLocked=false;
        currGiveawayId=0;
    }

    function getFees(uint percentage) public onlyOwner {
        uint totalGiveaways = giveawayNumber.current();
        uint totalLiveAmount = 0; 
        for(uint i=0 ; i<totalGiveaways ; i++)
        {
            uint currId = giveawayMap[i+1].uniqueId;
            Giveaway storage currGiveaway = giveawayMap[currId];
            if(currGiveaway.isLive==true)
            {
                totalLiveAmount += currGiveaway.amount;
            }

        }
        uint remainingFees = (address(this).balance - totalLiveAmount)/percentage;
        payable(owner).transfer(remainingFees);
    } 

}

