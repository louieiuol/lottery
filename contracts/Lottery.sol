//SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";


contract Lottery is payable{

    address payable[] public players;

    uint256 public usdEntryFee;

    uint256 public randomness;

    address payable public recentWinner;

    AggregatorV3Interface internal ethUsdPriceFeed;

    enum LOTTERY_STATE{
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    //0, 1, 2

    LOTTERY_STATE public lottery_state;
    uint256 public fee;
    bytes32 public keyhash;

    constructor(address _priceFeedAddress, 
                address _vrfCoordinator,
                address _link,
                uint256 _fee
        ) public VRFConsumerBase() {
        usdEntryFee = 50 * (10 ** 18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable{
        //$50 minimum
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not Enough ETH");
        players.push(msg.sender);
    }

    function startLottery() public {
        require(lottery_state == LOTTERY_STATE.CLOSED, "Can't start a new lottery yet!");
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function getEntranceFee() public view returns(uint256) {
        (, int256 price, , ,) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * (10 ** 10); //18 decimals
        uint256 costToEnter = (usdEntryFee * 10 ** 18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public{}

    function endLottery() public onlyOwner {
        // //not acceptable way
        // uint(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce, //nonce is predictable
        //             msg.sender, //msg.sender is predictable
        //             block.difficulty, // can actually by maniplated by the miners!
        //             block.timestamp //is predictable)
        //         );
        //     ) % players.length;

        //Chainlink VRF
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee);
    }

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness) internal override {
        require(lottery_state == LOTTERY_STATE.CALCULATING_WINNER, "You aren't there yet!");
        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance);

        //Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
}