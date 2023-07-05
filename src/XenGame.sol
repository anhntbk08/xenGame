// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "forge-std/console.sol";

interface IXENnftContract {
    function ownerOf(uint256 tokenId) external view returns (address);
}

interface INFTRegistry {
    function registerNFT(uint256 tokenId) external;
    function isNFTRegistered(uint256 tokenId) external view returns (bool);
    function addToPool() external payable;
}

interface XENBurn {
    function deposit() external payable returns (bool);
}

interface IPlayerNameRegistry {
    function registerPlayerName(address _address, string memory _name) external payable;
    function getPlayerAddress(string memory _name) external view returns (address);
    function getPlayerFirstName(address playerAddress) external view returns (string memory);
}


contract XenGame {
    IXENnftContract public nftContract;
    INFTRegistry public nftRegistry;
    XENBurn public xenBurn;
    IPlayerNameRegistry private playerNameRegistry;


    uint constant KEY_RESET_PERCENTAGE = 1; // 0.001% or 1 basis point
    uint constant NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
    uint constant KEY_PRICE_INCREMENT_PERCENTAGE = 10; // 0.099% or approx 10 basis points
    uint constant REFERRAL_REWARD_PERCENTAGE = 1000;  // 10% or 1000 basis points
    uint constant NFT_POOL_PERCENTAGE = 500;   // 5% or 500 basis points
    uint constant ROUND_GAP = 1 hours;  // *********************************************************updated to 1 hour for testing 
    uint constant EARLY_BUYIN_DURATION = 300; // *********************************************************** updated to 5 min  for testing 

    uint constant KEYS_FUND_PERCENTAGE = 5000;  // 50% or 5000 basis points
    uint constant JACKPOT_PERCENTAGE = 3000;  // 30% or 3000 basis points
    uint constant BURN_FUND_PERCENTAGE = 1500;  // 15% or 1500 basis points
    uint constant APEX_FUND_PERCENTAGE = 500;  // 5% or 5000 basis points
    uint constant PRECISION = 10**18;
    uint public devFund;

    struct Player {
        mapping(uint => uint) keyCount; //round to keys
        mapping(uint => uint) earlyBuyinPoints; // Track early buyin points for each round
        uint round;
        uint referralRewards;
        string lastReferrer;  // Track last referrer name        
        mapping(uint => uint) lastRewardRatio; // New variable
    }

    struct Round {
        uint totalKeys;
        uint totalFunds;
        uint start;
        uint end;
        address activePlayer;
        bool ended;
        bool isEarlyBuyin;
        uint keysFunds;    // ETH dedicated to key holders
        uint jackpot;      // ETH for the jackpot
        uint earlyBuyinEth; // Total ETH received during the early buy-in period
        uint lastKeyPrice; // The last key price for this round
        uint rewardRatio;
    }


    uint public currentRound = 0; 
    mapping(address => Player) public players;
    mapping(uint => Round) public rounds;
    mapping(string => address) public nameToAddress;
    mapping(address => mapping(uint => bool)) public earlyKeysReceived;
    

    constructor(address _nftContractAddress, address _nftRegistryAddress, address _xenBurnContract, address _playerNameRegistryAddress) {
        nftContract = IXENnftContract(_nftContractAddress);
        nftRegistry = INFTRegistry(_nftRegistryAddress);
        xenBurn = XENBurn(_xenBurnContract);
        playerNameRegistry = IPlayerNameRegistry(_playerNameRegistryAddress);
        startNewRound(); // add a starting date time
    }



    function buyWithReferral(string memory _referrerName, uint _numberOfKeys) public payable {

        console.log("function buyWithReferral", msg.sender, "tx.origin", tx.origin);    // TESTING line ------------------------------------------------


        Player storage player = players[msg.sender];
        string memory referrerName = bytes(_referrerName).length > 0 ? _referrerName : player.lastReferrer;
        address referrer = playerNameRegistry.getPlayerAddress(referrerName);

        if (referrer != address(0)) {
            uint referralReward = (msg.value * REFERRAL_REWARD_PERCENTAGE) / 10000;  // 10% of the incoming ETH
            
            if (referralReward > 0) { // Added check here to ensure referral reward is greater than 0
                uint splitReward = referralReward / 2;  // Split the referral reward

                // Add half of the referral reward to the referrer's stored rewards
                players[referrer].referralRewards += splitReward;

                // Add the other half of the referral reward to the player's stored rewards
                player.referralRewards += splitReward;
            }

            uint remaining = msg.value - referralReward;

            if (_numberOfKeys > 0) {
                buyCoreWithKeys(remaining, _numberOfKeys);
            } else {
                buyCore(remaining);
            }

            player.lastReferrer = referrerName;
        } else {
            if (_numberOfKeys > 0) {
                buyCoreWithKeys(msg.value, _numberOfKeys);
            } else {
                buyCore(msg.value);
            }
        }
    }




    function buyCore(uint _amount) private {

        console.log("function buyCore", msg.sender, "tx.origin", tx.origin);    // TESTING line ------------------------------------------------


        require(isRoundActive() || isRoundEnded(), "Cannot purchase keys during the round gap");

        if (isRoundActive()) {
        if (block.timestamp <= rounds[currentRound].start + EARLY_BUYIN_DURATION) {
            // If we are in the early buy-in period, follow early buy-in logic
            buyCoreEarly(_amount);
        } else if (!rounds[currentRound].ended) { // Add a check for round end here
            // Check if this is the first transaction after the early buy-in period
            if (rounds[currentRound].isEarlyBuyin) {
                updateTotalKeysForRound();
                finalizeEarlyBuyinPeriod();
            }

            if (rounds[currentRound].lastKeyPrice > calculateJackpotThreshold()) {
                uint newPrice = resetPrice();
                rounds[currentRound].lastKeyPrice = newPrice;
            }

            (uint maxKeysToPurchase,) = calculateMaxKeysToPurchase(_amount);

            // Update the reward ratio for the current round
            //rounds[currentRound].rewardRatio += ((_amount / 2) / (rounds[currentRound].totalKeys / 1 ether)); // using formatted keys  

            withdrawRewards(currentRound);

            if (players[msg.sender].lastRewardRatio[currentRound] == 0){
                players[msg.sender].lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio;
            }

            processKeyPurchase(maxKeysToPurchase, _amount);
            rounds[currentRound].activePlayer = msg.sender;
            adjustRoundEndTime(maxKeysToPurchase);
        }
    } else if (isRoundEnded()) {
        endRound();
        startNewRound();
    }
    }

    function buyCoreWithKeys(uint _amount, uint _numberOfKeys) private {

        console.log("function buyCoreWithKeys", msg.sender, "tx.origin", tx.origin);    // TESTING line ------------------------------------------------

        require(isRoundActive() || isRoundEnded(), "Cannot purchase keys during the round gap");

        if (isRoundActive()) {
        if (block.timestamp <= rounds[currentRound].start + EARLY_BUYIN_DURATION) {
            // If we are in the early buy-in period, follow early buy-in logic
            buyCoreEarly(_amount);

            console.log("enter Early Buying");
            console.log("early eth entered", rounds[currentRound].earlyBuyinEth);
        } else if (!rounds[currentRound].ended) {
            // Check if this is the first transaction after the early buy-in period
            if (rounds[currentRound].isEarlyBuyin) {
                console.log("First trans after early buying");
                updateTotalKeysForRound();
                finalizeEarlyBuyinPeriod();
            }

            if (rounds[currentRound].lastKeyPrice > calculateJackpotThreshold()) {
                console.log("enter jackpot threshold");
                uint newPrice = resetPrice();
                rounds[currentRound].lastKeyPrice = newPrice;
            }

            // Calculate cost for _numberOfKeys
            uint cost = calculatePriceForKeys(_numberOfKeys);
            require(cost <= _amount, "Not enough ETH to buy the specified number of keys");
            console.log("keys to buy cost ----------------", cost);
            console.log("current round keys", rounds[currentRound].totalKeys);
            console.log("current last key price:", rounds[currentRound].lastKeyPrice);

            // Update the reward ratio for the current round
            //rounds[currentRound].rewardRatio += (_amount / (rounds[currentRound].totalKeys / 1 ether)); // using formatted keys  

            withdrawRewards(currentRound);

            if (players[msg.sender].lastRewardRatio[currentRound] == 0) {
                players[msg.sender].lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio;
            }

            processKeyPurchase(_numberOfKeys, _amount);
            rounds[currentRound].activePlayer = msg.sender;
            adjustRoundEndTime(_numberOfKeys);
        }
    } else if (isRoundEnded()) {
        endRound();
        startNewRound();
    }
    }

    function buyKeysWithRewards() public {
        require(isRoundActive(), "Round is not active");

        Player storage player = players[msg.sender];

        checkForEarlyKeys();
        // Calculate the player's rewards
        uint256 reward = ((player.keyCount[currentRound] / 1 ether) * (rounds[currentRound].rewardRatio - player.lastRewardRatio[currentRound])); // using full keys for reward calc 

        require(reward > 0, "No rewards to withdraw");

        // Reset player's lastRewardRatio for the round
        player.lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio; // 

        // Calculate max keys that can be purchased with the reward
        (uint maxKeysToPurchase,) = calculateMaxKeysToPurchase(reward);

        // Make sure there are enough rewards to purchase at least one key
        require(maxKeysToPurchase > 0, "Not enough rewards to purchase any keys");

        // Update the reward ratio for the current round
        //updateRoundRatio(cost, currentRound);
        //rounds[currentRound].rewardRatio += (cost * PRECISION) / rounds[currentRound].totalKeys; // ****** Uddating using fractional keys *******

        // Process the key purchase
        
        processKeyPurchase(maxKeysToPurchase, reward);

        // Update the active player for the round
        rounds[currentRound].activePlayer = msg.sender;

        // Adjust the round end time based on the keys purchased
        adjustRoundEndTime(maxKeysToPurchase);
    }





    function buyCoreEarly(uint _amount) private {

        console.log("function buyCoreEarly", msg.sender, "tx.origin", tx.origin);    // TESTING line ------------------------------------------------

        // Accumulate the ETH and track the user's early buy-in points
        rounds[currentRound].earlyBuyinEth += _amount;
        players[msg.sender].earlyBuyinPoints[currentRound] += _amount;
        players[msg.sender].lastRewardRatio[currentRound] = 1;
        rounds[currentRound].isEarlyBuyin = true;
    }


    fallback() external payable {
        buyWithReferral("", 0);
    }

    receive() external payable {
        buyWithReferral("", 0);
    }



    function isRoundActive() public view returns (bool) {
        uint _roundId = currentRound;
        return block.timestamp >= rounds[_roundId].start && block.timestamp < rounds[_roundId].end;
    }

    function isRoundEnded() public view returns (bool) {
        uint _roundId = currentRound;
        return block.timestamp >= rounds[_roundId].end && !rounds[_roundId].ended;
    }

    
    function updateTotalKeysForRound() private {
        // Update total keys for the round with the starting keys
        rounds[currentRound].totalKeys += 10000000 ether;
    }

    function finalizeEarlyBuyinPeriod() private {

        console.log("---Finalize Early buy price called ------");

        // Set isEarlyBuyin to false to signify the early buy-in period is over
        rounds[currentRound].isEarlyBuyin = false;

        // Calculate the last key price for the round
        rounds[currentRound].lastKeyPrice = rounds[currentRound].earlyBuyinEth / (10**7); // using full keys  ********************************************

        // Set reward ratio
        //rounds[currentRound].rewardRatio = 1; // set low non

        // Add early buy-in funds to the jackpot
        rounds[currentRound].jackpot += rounds[currentRound].earlyBuyinEth;
    }



    function calculateMaxKeysToPurchase(uint _amount) public view returns (uint maxKeys, uint totalCost) {
        uint initialKeyPrice = getKeyPrice();
        uint left = 0;
        uint right = _amount / initialKeyPrice;
        uint _totalCost;

        while (left < right) {
            uint mid = (left + right + 1) / 2;
            _totalCost = calculatePriceForKeys(mid);
            
            if (_totalCost <= _amount) {
                left = mid;
            } else {
                right = mid - 1;
            }
        }

        maxKeys = left;
        _totalCost = calculatePriceForKeys(left);

        return (maxKeys, _totalCost);
    }

    function calculatePriceForKeys(uint _keys) public view returns (uint totalPrice) {
        uint initialKeyPrice = getKeyPrice();
        uint increasePerKey = 0.000000009 ether;
        
        if (_keys <= 1) {
            totalPrice = initialKeyPrice * _keys;
        } else {
            uint lastPrice = initialKeyPrice + ((_keys - 1) * increasePerKey);
            totalPrice = (_keys * (initialKeyPrice + lastPrice)) / 2;
        }

        return totalPrice;
    }


    function processKeyPurchase(uint maxKeysToPurchase, uint _amount) private {
        require(_amount >= 0, "Not enough Ether to purchase keys");

        uint fractionalKeys = maxKeysToPurchase * 1 ether;

        players[msg.sender].keyCount[currentRound] += fractionalKeys;
        rounds[currentRound].totalKeys += fractionalKeys;

        uint finalKeyPrice = rounds[currentRound].lastKeyPrice;

        uint increasePerKey = 0.000000009 ether;
        finalKeyPrice += increasePerKey * maxKeysToPurchase;

        rounds[currentRound].lastKeyPrice = finalKeyPrice;

        distributeFunds(_amount);
    }

    function checkForEarlyKeys() private {
        if (players[msg.sender].earlyBuyinPoints[currentRound] > 0 && !earlyKeysReceived[msg.sender][currentRound]) {
            // Calculate early keys based on the amount of early ETH sent
            uint totalPoints = rounds[currentRound].earlyBuyinEth;
            uint playerPoints = players[msg.sender].earlyBuyinPoints[currentRound];

            uint earlyKeys = ((playerPoints * 10_000_000) / totalPoints) * 1 ether;

            players[msg.sender].keyCount[currentRound] += earlyKeys;
            //players[msg.sender].lastRewardRatio[currentRound] = 1; // set small non Zero amount
            // Mark that early keys were received for this round
            earlyKeysReceived[msg.sender][currentRound] = true;


        }
    }



    function adjustRoundEndTime(uint maxKeysToPurchase) private {//----------------------------------------------------------
        uint timeExtension = maxKeysToPurchase * 30 seconds;
        uint maxEndTime = block.timestamp + 12 hours;
        rounds[currentRound].end = min(rounds[currentRound].end + timeExtension, maxEndTime);
    }

    function getKeyPrice() public view returns (uint) {
        uint _roundId = currentRound;

        
            // Use the last key price set for this round, whether it's from the Early Buy-in period or elsewhere
            return rounds[_roundId].lastKeyPrice;
        
    }


    function calculateJackpotThreshold() private view returns (uint) {
        uint _roundId = currentRound;
        return rounds[_roundId].jackpot / 1000000; // 0.0001% of the jackpot
    }

    function resetPrice() private view returns (uint) {
        uint _roundId = currentRound;
        return rounds[_roundId].jackpot / 10000000; // 0.00001% of the jackpot
    }

    function updateRoundRatio (uint _amount, uint _roundNumber) private {
        rounds[_roundNumber].rewardRatio += (_amount / (rounds[currentRound].totalKeys / 1 ether));
    }

    function distributeFunds(uint _amount) private {

        console.log("distrubute funds called with amount ", _amount);
        uint keysFund = (_amount * KEYS_FUND_PERCENTAGE) / 10000;
        console.log("Key funds sent", keysFund);
        //rounds[currentRound].keysFunds += keysFund;

        updateRoundRatio(keysFund, currentRound);
        //rounds[currentRound].rewardRatio += (keysFund / (rounds[currentRound].totalKeys / 1 ether)); // updating ratio with full keys 

        uint jackpot = (_amount * JACKPOT_PERCENTAGE) / 10000;
        rounds[currentRound].jackpot += jackpot;

        uint apexFund = (_amount * APEX_FUND_PERCENTAGE) / 10000;

        // Transfer the apex fund to the nftRegistry
        nftRegistry.addToPool{value: apexFund}();

        uint burnFund = (_amount * BURN_FUND_PERCENTAGE) / 10000;
        xenBurn.deposit{value: burnFund}();

        rounds[currentRound].totalFunds += _amount - apexFund - burnFund; // Subtracting amounts that left the contract
    }

    
    function registerPlayerName( string memory name) public payable{
        require(msg.value >= NAME_REGISTRATION_FEE, "Insufficient funds to register the name.");
        playerNameRegistry.registerPlayerName{value: msg.value}(msg.sender,name);
    }



    function registerNFT(uint256 tokenId) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "You don't own this NFT.");
        
        nftRegistry.registerNFT(tokenId);
    }

    function buyAndBurn() public {
        
        // Burn fund logic
    }

    
    function withdrawRewards(uint roundNumber) public {
        Player storage player = players[msg.sender];

        checkForEarlyKeys();

        uint256 reward = ((player.keyCount[roundNumber] * (rounds[roundNumber].rewardRatio - player.lastRewardRatio[roundNumber])) / PRECISION);
        player.lastRewardRatio[roundNumber] = rounds[roundNumber].rewardRatio;

        if (reward > 0) {
            // Transfer the rewards
            (bool success, ) = msg.sender.call{value: reward}("");
            require(success, "Transfer failed");

            emit RewardsWithdrawn(msg.sender, reward, block.timestamp);
        }
    }

    function withdrawReferralRewards() public {
        uint256 rewardAmount = players[msg.sender].referralRewards;
        require(rewardAmount > 0, "No referral rewards to withdraw");

        // Reset the player's referral rewards before sending to prevent re-entrancy attacks
        players[msg.sender].referralRewards = 0;

        // transfer the rewards
        (bool success, ) = msg.sender.call{value: rewardAmount}("");
        require(success, "Transfer failed.");

        emit ReferralRewardsWithdrawn(msg.sender, rewardAmount, block.timestamp);
    }


    function endRound() private {
        Round storage round = rounds[currentRound];
        require(block.timestamp > round.end, "Round has not yet ended.");

        // Identify the winner as the last person to have bought a key
        address winner = round.activePlayer;

        // Divide the jackpot
        uint jackpot = round.jackpot;
        uint winnerShare = (jackpot * 50) / 100; // 50%
        uint keysFundsShare = (jackpot * 20) / 100; // 20%
        uint currentRoundNftShare = (jackpot * 20) / 100; // 20%
        uint nextRoundJackpot = (jackpot * 10) / 100; // 10%

        // Transfer to the winner
        payable(winner).transfer(winnerShare);

        // Add to the keysFunds
        //round.keysFunds += keysFundsShare;// ***************************************************adjust the new key ratio 
        updateRoundRatio(keysFundsShare, currentRound);
        // Set the starting jackpot for the next round
        rounds[currentRound + 1].jackpot = nextRoundJackpot;

        // Send to the NFT contract
        nftRegistry.addToPool{value: currentRoundNftShare}();

        round.ended = true;
    }




    function startNewRound() private {
        currentRound += 1; 
        rounds[currentRound].start = block.timestamp + ROUND_GAP; // Add ROUND_GAP to the start time
        rounds[currentRound].end = rounds[currentRound].start + 2 hours;  // Set end time to start time + round duration  **************chnaged starting time for testing 
        rounds[currentRound].ended = false;
    }

    function getPendingRewards(address playerAddress, uint roundNumber) public view returns (uint256) {
        Player storage player = players[playerAddress];
        uint256 pendingRewards = (player.keyCount[currentRound] * (rounds[roundNumber].rewardRatio - player.lastRewardRatio[roundNumber])) / PRECISION;
        return pendingRewards;
    }

    function getPlayerKeysCount(address playerAddress, uint _round) public view returns (uint) {
        Player storage player = players[playerAddress];

        if (player.earlyBuyinPoints[_round] > 0 && !earlyKeysReceived[playerAddress][_round]) {
            // Calculate early keys based on the amount of early ETH sent
            uint totalPoints = rounds[_round].earlyBuyinEth;
            uint playerPoints = players[playerAddress].earlyBuyinPoints[_round];

            uint earlyKeys = ((playerPoints * 10_000_000) / totalPoints) * 1 ether;

            return (player.keyCount[_round] + earlyKeys);
        } else {
            return player.keyCount[_round];
        }
    }

    function getPlayerName(address playerAddress) public view returns (string memory) {
        return playerNameRegistry.getPlayerFirstName(playerAddress);
    }

    function getRoundStats(uint roundId) public view returns (
        uint totalKeys, 
        uint totalFunds, 
        uint start, 
        uint end, 
        address activePlayer, 
        bool ended, 
        bool isEarlyBuyin,
        uint keysFunds,
        uint jackpot,
        uint earlyBuyinEth,
        uint lastKeyPrice,
        uint rewardRatio
    ) {
        Round memory round = rounds[roundId];
        return (
            round.totalKeys, 
            round.totalFunds, 
            round.start, 
            round.end, 
            round.activePlayer, 
            round.ended, 
            round.isEarlyBuyin,
            round.keysFunds,
            round.jackpot,
            round.earlyBuyinEth,
            round.lastKeyPrice,
            round.rewardRatio
        );
    }

    function getPlayerInfo(address playerAddress, uint roundNumber) public view returns (
        uint keyCount,
        uint earlyBuyinPoints,
        uint referralRewards,
        uint lastRewardRatio
    ) {
        keyCount = getPlayerKeysCount(playerAddress, roundNumber);
        earlyBuyinPoints = players[playerAddress].earlyBuyinPoints[roundNumber];
        referralRewards = players[playerAddress].referralRewards;
        lastRewardRatio = players[playerAddress].lastRewardRatio[roundNumber];
    }


    function getRoundStart(uint roundId) public view returns (uint) {
        return rounds[roundId].start;
    }

    function getRoundEarlyBuyin(uint roundId) public view returns (uint) {
        return rounds[roundId].earlyBuyinEth;
    }

    function min(uint a, uint b) private pure returns (uint) {
        return a < b ? a : b;
    }

    function max(uint a, uint b) private pure returns (uint) {
        return a > b ? a : b;
    }

    event BuyAndDistribute(address buyer, uint amount);
    event ReferralRewardsWithdrawn(address indexed player, uint256 amount, uint256 timestamp);
    event RewardsWithdrawn(address indexed player, uint256 amount, uint256 timestamp);

}
