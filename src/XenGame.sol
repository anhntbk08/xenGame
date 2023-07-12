// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

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

    uint256 constant KEY_RESET_PERCENTAGE = 1; // 0.001% or 1 basis point
    uint256 constant NAME_REGISTRATION_FEE = 20000000000000000; // 0.02 Ether in Wei
    uint256 constant KEY_PRICE_INCREMENT_PERCENTAGE = 10; // 0.099% or approx 10 basis points
    uint256 constant REFERRAL_REWARD_PERCENTAGE = 1000; // 10% or 1000 basis points
    uint256 constant NFT_POOL_PERCENTAGE = 500; // 5% or 500 basis points
    uint256 constant ROUND_GAP = 1 hours; // *********************************************************updated to 1 hour for testing
    uint256 constant EARLY_BUYIN_DURATION = 300; // *********************************************************** updated to 5 min  for testing

    uint256 constant KEYS_FUND_PERCENTAGE = 5000; // 50% or 5000 basis points
    uint256 constant JACKPOT_PERCENTAGE = 3000; // 30% or 3000 basis points
    uint256 constant BURN_FUND_PERCENTAGE = 1500; // 15% or 1500 basis points
    uint256 constant APEX_FUND_PERCENTAGE = 500; // 5% or 5000 basis points
    uint256 constant PRECISION = 10 ** 18;
    uint256 public devFund;

    struct Player {
        mapping(uint256 => uint256) keyCount; //round to keys
        mapping(uint256 => uint256) earlyBuyinPoints; // Track early buyin points for each round
        uint256 referralRewards;
        string lastReferrer; // Track last referrer name
        mapping(uint256 => uint256) lastRewardRatio; // New variable
        uint256 keyRewards;
        uint256 numberOfReferrals; 
    }

    struct Round {
        uint256 totalKeys;
        uint256 totalFunds;
        uint256 start;
        uint256 end;
        address activePlayer;
        bool ended;
        bool isEarlyBuyin;
        uint256 keysFunds; // ETH dedicated to key holders
        uint256 jackpot; // ETH for the jackpot
        uint256 earlyBuyinEth; // Total ETH received during the early buy-in period
        uint256 lastKeyPrice; // The last key price for this round
        uint256 rewardRatio;
    }

    uint256 public currentRound = 0;
    mapping(address => Player) public players;
    mapping(uint256 => Round) public rounds;
    mapping(string => address) public nameToAddress;
    mapping(address => mapping(uint256 => bool)) public earlyKeysReceived;

    constructor(
        address _nftContractAddress,
        address _nftRegistryAddress,
        address _xenBurnContract,
        address _playerNameRegistryAddress
    ) {
        nftContract = IXENnftContract(_nftContractAddress);
        nftRegistry = INFTRegistry(_nftRegistryAddress);
        xenBurn = XENBurn(_xenBurnContract);
        playerNameRegistry = IPlayerNameRegistry(_playerNameRegistryAddress);
        startNewRound(); // add a starting date time
    }

    function buyWithReferral(string memory _referrerName, uint256 _numberOfKeys) public payable {
        Player storage player = players[msg.sender];
        string memory referrerName = bytes(_referrerName).length > 0 ? _referrerName : player.lastReferrer;
        address referrer = playerNameRegistry.getPlayerAddress(referrerName);

        if (referrer != address(0)) {
            uint256 referralReward = (msg.value * REFERRAL_REWARD_PERCENTAGE) / 10000; // 10% of the incoming ETH

            if (referralReward > 0) {
                // Added check here to ensure referral reward is greater than 0
                uint256 splitReward = referralReward / 2; // Split the referral reward

                // Add half of the referral reward to the referrer's stored rewards
                players[referrer].referralRewards += splitReward;
                players[referrer].numberOfReferrals++;

                // Add the other half of the referral reward to the player's stored rewards
                player.referralRewards += splitReward;

                emit ReferralPaid(msg.sender, referrer, splitReward, block.timestamp);
            }

            uint256 remaining = msg.value - referralReward;

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

    function buyCore(uint256 _amount) private {
        require(isRoundActive() || isRoundEnded(), "Cannot purchase keys during the round gap");

        if (isRoundEnded()) {
            endRound();
            startNewRound();
            players[msg.sender].keyRewards += _amount;
            return;
        }

        if (isRoundActive()) {
            if (block.timestamp <= rounds[currentRound].start + EARLY_BUYIN_DURATION) {
                // If we are in the early buy-in period, follow early buy-in logic
                buyCoreEarly(_amount);
            } else if (!rounds[currentRound].ended) {
                // Add a check for round end here
                // Check if this is the first transaction after the early buy-in period
                if (rounds[currentRound].isEarlyBuyin) {
                    updateTotalKeysForRound();
                    finalizeEarlyBuyinPeriod();
                }

                if (rounds[currentRound].lastKeyPrice > calculateJackpotThreshold()) {
                    uint256 newPrice = resetPrice();
                    rounds[currentRound].lastKeyPrice = newPrice;
                }

                (uint256 maxKeysToPurchase, uint256 totalCost) = calculateMaxKeysToPurchase(_amount);
                    uint256 remainingEth = _amount - totalCost;

                // Transfer any remaining ETH back to the player and store it in their key rewards
                if (remainingEth > 0) {
                    players[msg.sender].keyRewards += remainingEth;
                }

                processRewards(currentRound);

                if (players[msg.sender].lastRewardRatio[currentRound] == 0) {
                    players[msg.sender].lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio;
                }

                processKeyPurchase(maxKeysToPurchase, totalCost);
                rounds[currentRound].activePlayer = msg.sender;
                adjustRoundEndTime(maxKeysToPurchase);
            }
        } 
    }

    function buyCoreWithKeys(uint256 _amount, uint256 _numberOfKeys) private {
        require(isRoundActive() || isRoundEnded(), "Cannot purchase keys during the round gap");

        if (isRoundEnded()) {
            endRound();
            startNewRound();
            players[msg.sender].keyRewards += _amount;
            return;
        }

        if (isRoundActive()) {
            if (block.timestamp <= rounds[currentRound].start + EARLY_BUYIN_DURATION) {
                // If we are in the early buy-in period, follow early buy-in logic
                buyCoreEarly(_amount);
            } else if (!rounds[currentRound].ended) {
                // Check if this is the first transaction after the early buy-in period
                if (rounds[currentRound].isEarlyBuyin) {
                    updateTotalKeysForRound();
                    finalizeEarlyBuyinPeriod();
                }

                if (rounds[currentRound].lastKeyPrice > calculateJackpotThreshold()) {
                    uint256 newPrice = resetPrice();
                    rounds[currentRound].lastKeyPrice = newPrice;
                }

                // Calculate cost for _numberOfKeys
                uint256 cost = calculatePriceForKeys(_numberOfKeys);
                require(cost <= _amount, "Not enough ETH to buy the specified number of keys");

                uint256 remainingEth = _amount - cost;


                processRewards(currentRound);

                if (players[msg.sender].lastRewardRatio[currentRound] == 0) {
                    players[msg.sender].lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio;
                }

                processKeyPurchase(_numberOfKeys, cost);
                rounds[currentRound].activePlayer = msg.sender;
                adjustRoundEndTime(_numberOfKeys);

                if (remainingEth > 0) {
                    players[msg.sender].keyRewards += remainingEth;
                }
            }
        } 
    }

    function buyKeysWithRewards() public {
        require(isRoundActive(), "Round is not active");

        Player storage player = players[msg.sender];

        checkForEarlyKeys();
        // Calculate the player's rewards
        uint256 reward = (
            (player.keyCount[currentRound] / 1 ether)
                * (rounds[currentRound].rewardRatio - player.lastRewardRatio[currentRound])
        ); // using full keys for reward calc

        // Add any keyRewards to the calculated reward
        reward += player.keyRewards;

        // Reset player's keyRewards
        player.keyRewards = 0;

        require(reward > 0, "No rewards to withdraw");

        // Reset player's lastRewardRatio for the round
        player.lastRewardRatio[currentRound] = rounds[currentRound].rewardRatio; //

        // Calculate max keys that can be purchased with the reward
        (uint256 maxKeysToPurchase,) = calculateMaxKeysToPurchase(reward);

        // Make sure there are enough rewards to purchase at least one key
        require(maxKeysToPurchase > 0, "Not enough rewards to purchase any keys");

        // Buy keys using rewards
        buyCore(reward);
    }

    function buyCoreEarly(uint256 _amount) private {
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
        uint256 _roundId = currentRound;
        return block.timestamp >= rounds[_roundId].start && block.timestamp < rounds[_roundId].end;
    }

    function isRoundEnded() public view returns (bool) {
        uint256 _roundId = currentRound;
        return block.timestamp >= rounds[_roundId].end;
    }

    function updateTotalKeysForRound() private {
        // Update total keys for the round with the starting keys
        rounds[currentRound].totalKeys += 10000000 ether;
        if (rounds[currentRound].earlyBuyinEth > 0) {
            rounds[currentRound].totalKeys += 10000000 ether;
        } else {
            rounds[currentRound].totalKeys += 1 ether;
        }
    }

    function finalizeEarlyBuyinPeriod() private {
        // Set isEarlyBuyin to false to signify the early buy-in period is over
        rounds[currentRound].isEarlyBuyin = false;

        // Calculate the last key price for the round
        if (rounds[currentRound].earlyBuyinEth > 0) {
            rounds[currentRound].lastKeyPrice = rounds[currentRound].earlyBuyinEth / (10 ** 7); // using full keys
        } else {
            rounds[currentRound].lastKeyPrice = 0.000000009 ether; // Set to 0.000000009 ether if there is no early buying ETH or no keys purchased
        }

        // Set reward ratio
        rounds[currentRound].rewardRatio = 1; // set low non

        // Add early buy-in funds to the jackpot
        rounds[currentRound].jackpot += rounds[currentRound].earlyBuyinEth;
    }

    function calculateMaxKeysToPurchase(uint256 _amount) public view returns (uint256 maxKeys, uint256 totalCost) {
        uint256 initialKeyPrice = getKeyPrice();
        uint256 left = 0;
        uint256 right = _amount / initialKeyPrice;
        uint256 _totalCost;

        while (left < right) {
            uint256 mid = (left + right + 1) / 2;
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

    function calculatePriceForKeys(uint256 _keys) public view returns (uint256 totalPrice) {
        uint256 initialKeyPrice = getKeyPrice();
        uint256 increasePerKey = 0.000000009 ether;

        if (_keys <= 1) {
            totalPrice = initialKeyPrice * _keys;
        } else {
            uint256 lastPrice = initialKeyPrice + ((_keys - 1) * increasePerKey);
            totalPrice = (_keys * (initialKeyPrice + lastPrice)) / 2;
        }

        return totalPrice;
    }

    function processKeyPurchase(uint256 maxKeysToPurchase, uint256 _amount) private {
        require(_amount >= 0, "Not enough Ether to purchase keys");

        uint256 fractionalKeys = maxKeysToPurchase * 1 ether;

        players[msg.sender].keyCount[currentRound] += fractionalKeys;
        rounds[currentRound].totalKeys += fractionalKeys;

        uint256 finalKeyPrice = rounds[currentRound].lastKeyPrice;

        uint256 increasePerKey = 0.000000009 ether;
        finalKeyPrice += increasePerKey * maxKeysToPurchase;

        rounds[currentRound].lastKeyPrice = finalKeyPrice;

        distributeFunds(_amount);
        emit BuyAndDistribute(msg.sender,  maxKeysToPurchase, finalKeyPrice,  block.timestamp);
    }

    function checkForEarlyKeys() private {
        if (players[msg.sender].earlyBuyinPoints[currentRound] > 0 && !earlyKeysReceived[msg.sender][currentRound]) {
            // Calculate early keys based on the amount of early ETH sent
            uint256 totalPoints = rounds[currentRound].earlyBuyinEth;
            uint256 playerPoints = players[msg.sender].earlyBuyinPoints[currentRound];

            uint256 earlyKeys = ((playerPoints * 10_000_000) / totalPoints) * 1 ether;

            players[msg.sender].keyCount[currentRound] += earlyKeys;
            //players[msg.sender].lastRewardRatio[currentRound] = 1; // set small non Zero amount
            // Mark that early keys were received for this round
            earlyKeysReceived[msg.sender][currentRound] = true;
        }
    }

    function adjustRoundEndTime(uint256 maxKeysToPurchase) private {
        //----------------------------------------------------------
        uint256 timeExtension = maxKeysToPurchase * 30 seconds;
        uint256 maxEndTime = block.timestamp + 12 hours;
        rounds[currentRound].end = min(rounds[currentRound].end + timeExtension, maxEndTime);
    }

    function getKeyPrice() public view returns (uint256) {
        uint256 _roundId = currentRound;

        // Use the last key price set for this round, whether it's from the Early Buy-in period or elsewhere
        return rounds[_roundId].lastKeyPrice;
    }

    function calculateJackpotThreshold() private view returns (uint256) {
        uint256 _roundId = currentRound;
        return rounds[_roundId].jackpot / 1000000; // 0.0001% of the jackpot
    }

    function resetPrice() private view returns (uint256) {
        uint256 _roundId = currentRound;
        return rounds[_roundId].jackpot / 10000000; // 0.00001% of the jackpot
    }

    function updateRoundRatio(uint256 _amount, uint256 _roundNumber) private {
        rounds[_roundNumber].rewardRatio += (_amount / (rounds[currentRound].totalKeys / 1 ether));
    }

    function distributeFunds(uint256 _amount) private {
        uint256 keysFund = (_amount * KEYS_FUND_PERCENTAGE) / 10000;

        updateRoundRatio(keysFund, currentRound);
        

        uint256 jackpot = (_amount * JACKPOT_PERCENTAGE) / 10000;
        rounds[currentRound].jackpot += jackpot;

        uint256 apexFund = (_amount * APEX_FUND_PERCENTAGE) / 10000;

        // Transfer the apex fund to the nftRegistry
        nftRegistry.addToPool{value: apexFund}();

        uint256 burnFund = (_amount * BURN_FUND_PERCENTAGE) / 10000;
        xenBurn.deposit{value: burnFund}();

        rounds[currentRound].totalFunds += _amount - apexFund - burnFund; // Subtracting amounts that left the contract
    }

    function registerPlayerName(string memory name) public payable {
        require(msg.value >= NAME_REGISTRATION_FEE, "Insufficient funds to register the name.");
        playerNameRegistry.registerPlayerName{value: msg.value}(msg.sender, name);
        emit PlayerNameRegistered(msg.sender, name, block.timestamp);

    }

    function registerNFT(uint256 tokenId) external {
        require(nftContract.ownerOf(tokenId) == msg.sender, "You don't own this NFT.");

        nftRegistry.registerNFT(tokenId);
    }

    function processRewards(uint256 roundNumber) private  {
        Player storage player = players[msg.sender];

        checkForEarlyKeys();

        // Only calculate rewards if player has at least one key
        if (player.keyCount[roundNumber] > 0) {
            // Calculate the player's rewards
            uint256 reward = (
                (player.keyCount[roundNumber] / 1 ether)
                    * (rounds[roundNumber].rewardRatio - player.lastRewardRatio[roundNumber])
            ); 

            player.lastRewardRatio[roundNumber] = rounds[roundNumber].rewardRatio;

            // Add the reward to the player's keyRewards instead of sending it
            player.keyRewards += reward;
        }
    }

    function buyAndBurn() public {
        // Burn fund logic
    }

    function withdrawRewards(uint256 roundNumber) public {
    Player storage player = players[msg.sender];
    address payable senderPayable = payable(msg.sender);  // Explicit casting


    checkForEarlyKeys();

    uint256 reward = (
        (player.keyCount[roundNumber] / 1 ether)
            * (rounds[roundNumber].rewardRatio - player.lastRewardRatio[roundNumber])
    );

    player.lastRewardRatio[roundNumber] = rounds[roundNumber].rewardRatio;

    // Add the preprocessed keyRewards to the normal rewards
    reward += player.keyRewards;

    // Reset the player's keyRewards
    player.keyRewards = 0;

    if (reward > 0) {
        // Transfer the rewards
        senderPayable.transfer(reward);

        emit RewardsWithdrawn(msg.sender, reward, block.timestamp);
    }
}

function withdrawReferralRewards() public {
    uint256 rewardAmount = players[msg.sender].referralRewards;
    require(rewardAmount > 0, "No referral rewards to withdraw");
    // Check that the player has a registered name
    string memory playerName = getPlayerName(msg.sender);
    require(bytes(playerName).length > 0, "Player has no registered names");



    address payable senderPayable = payable(msg.sender);  // Explicit casting


    // Reset the player's referral rewards before sending to prevent re-entrancy attacks
    players[msg.sender].referralRewards = 0;

    // transfer the rewards
    senderPayable.transfer(rewardAmount);

    emit ReferralRewardsWithdrawn(msg.sender, rewardAmount, block.timestamp);
}


    function endRound() private {
        Round storage round = rounds[currentRound];
        require(block.timestamp > round.end, "Round has not yet ended.");

        // Identify the winner as the last person to have bought a key
        address winner = round.activePlayer;

        // Divide the jackpot
        uint256 jackpot = round.jackpot;
        uint256 winnerShare = (jackpot * 50) / 100; // 50%
        uint256 keysFundsShare = (jackpot * 20) / 100; // 20%
        uint256 currentRoundNftShare = (jackpot * 20) / 100; // 20%
        uint256 nextRoundJackpot = (jackpot * 10) / 100; // 10%

        // Transfer to the winner
        payable(winner).transfer(winnerShare);

        // Add to the keysFunds
        updateRoundRatio(keysFundsShare, currentRound);

        // Set the starting jackpot for the next round
        rounds[currentRound + 1].jackpot = nextRoundJackpot;

        // Send to the NFT contract
        nftRegistry.addToPool{value: currentRoundNftShare}();

        round.ended = true;

        emit RoundEnded(currentRound, winner, jackpot, winnerShare, keysFundsShare, currentRoundNftShare, nextRoundJackpot, block.timestamp);
    }

    function startNewRound() private {
        currentRound += 1;
        rounds[currentRound].start = block.timestamp + ROUND_GAP; // Add ROUND_GAP to the start time
        rounds[currentRound].end = rounds[currentRound].start + 2 hours; // Set end time to start time + round duration  **************chnaged starting time for testing
        rounds[currentRound].ended = false;
        emit NewRoundStarted(currentRound, rounds[currentRound].start, rounds[currentRound].end);
    }

    function getPendingRewards(address playerAddress, uint256 roundNumber) public view returns (uint256) {
        Player storage player = players[playerAddress];
        uint256 pendingRewards = (
            player.keyCount[currentRound] * (rounds[roundNumber].rewardRatio - player.lastRewardRatio[roundNumber])
        ) / PRECISION;

        // Add the keyRewards to the pending rewards
        pendingRewards += player.keyRewards;

        return pendingRewards;
    }


    function getPlayerKeysCount(address playerAddress, uint256 _round) public view returns (uint256) {
        Player storage player = players[playerAddress];

        if (player.earlyBuyinPoints[_round] > 0 && !earlyKeysReceived[playerAddress][_round]) {
            // Calculate early keys based on the amount of early ETH sent
            uint256 totalPoints = rounds[_round].earlyBuyinEth;
            uint256 playerPoints = players[playerAddress].earlyBuyinPoints[_round];

            uint256 earlyKeys = ((playerPoints * 10_000_000) / totalPoints) * 1 ether;

            return (player.keyCount[_round] + earlyKeys);
        } else {
            return player.keyCount[_round];
        }
    }

    function getPlayerName(address playerAddress) public view returns (string memory) {
        return playerNameRegistry.getPlayerFirstName(playerAddress);
    }

    function getRoundStats(uint256 roundId)
        public
        view
        returns (
            uint256 totalKeys,
            uint256 totalFunds,
            uint256 start,
            uint256 end,
            address activePlayer,
            bool ended,
            bool isEarlyBuyin,
            uint256 keysFunds,
            uint256 jackpot,
            uint256 earlyBuyinEth,
            uint256 lastKeyPrice,
            uint256 rewardRatio
        )
    {
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

    function getPlayerInfo(address playerAddress, uint256 roundNumber)
        public
        view
        returns (
            uint256 keyCount, 
            uint256 earlyBuyinPoints, 
            uint256 referralRewards, 
            uint256 lastRewardRatio,
            uint256 keyRewards,
            uint256 numberOfReferrals
        )
    {
        keyCount = getPlayerKeysCount(playerAddress, roundNumber);
        earlyBuyinPoints = players[playerAddress].earlyBuyinPoints[roundNumber];
        referralRewards = players[playerAddress].referralRewards;
        lastRewardRatio = players[playerAddress].lastRewardRatio[roundNumber];
        keyRewards = getPendingRewards(playerAddress,  roundNumber);
        numberOfReferrals = players[playerAddress].numberOfReferrals;
    }


    function getRoundStart(uint256 roundId) public view returns (uint256) {
        return rounds[roundId].start;
    }

    function getRoundEarlyBuyin(uint256 roundId) public view returns (uint256) {
        return rounds[roundId].earlyBuyinEth;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    event BuyAndDistribute(address buyer, uint256 amount, uint256 keyPrice, uint256 timestamp);
    event ReferralRewardsWithdrawn(address indexed player, uint256 amount, uint256 timestamp);
    event RewardsWithdrawn(address indexed player, uint256 amount, uint256 timestamp);
    event RoundEnded(uint256 roundId, address winner, uint256 jackpot, uint256 winnerShare, uint256 keysFundsShare, uint256 currentRoundNftShare, uint256 nextRoundJackpot, uint256 timestamp);
    event NewRoundStarted(uint256 roundId, uint256 startTimestamp, uint256 endTimestamp);
    event PlayerNameRegistered(address player, string name, uint256 timestamp);
    event ReferralPaid(address player, address referrer, uint256 amount, uint256 timestamp);

}
