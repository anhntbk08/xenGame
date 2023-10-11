
pragma solidity 0.8.17;
import "../src/XenGameV2.sol";

contract XenGameT is XenGame {
    constructor(
        address _nftContractAddress,
        address _nftRegistryAddress,
        address _xenBurnContract,
        address _playerNameRegistryAddress
    ) XenGame(_nftContractAddress, _nftRegistryAddress, _xenBurnContract, _playerNameRegistryAddress) { }

    function startNewRoundO() public  {
        // Increment the current round number
        currentRound += 1;

        // Set the start time of the new round by adding ROUND_GAP to the current timestamp
        rounds[currentRound].start = block.timestamp + ROUND_GAP;

        // Set the end time of the new round by adding 1 hour to the start time (adjust as needed)
        rounds[currentRound].end = rounds[currentRound].start + 12 hours;

        // Reset the "ended" flag for the new round
        rounds[currentRound].ended = false;

        // Set the reward ratio to a low non-zero value
        rounds[currentRound].rewardRatio = 1; 
       
        emit NewRoundStarted(currentRound, rounds[currentRound].start, rounds[currentRound].end);
    }
}