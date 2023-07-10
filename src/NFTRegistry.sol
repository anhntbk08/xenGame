// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IXENNFTContract {
    function ownerOf(uint256) external view returns (address);
}

contract NFTRegistry {
    struct NFT {
        uint256 tokenId;
        string category;
    }

    struct User {
        NFT[] userNFTs;
        uint256 userRewards; // Tracks total rewards sebt to user.
        uint256 userPoints;
        uint256 userLastRewarded; //-----------------
        uint256 lastRewardRatio;
    }

    mapping(address => User) public users;
    mapping(uint256 => string) private categoryMap;
    mapping(uint256 => address) public currentHolder;

    uint256 private constant XUNICORN_MIN_ID = 1;
    uint256 private constant XUNICORN_MAX_ID = 100;
    uint256 private constant EXOTIC_MIN_ID = 101;
    uint256 private constant EXOTIC_MAX_ID = 1000;
    uint256 private constant LEGENDARY_MIN_ID = 1001;
    uint256 private constant LEGENDARY_MAX_ID = 3000;
    uint256 private constant EPIC_MIN_ID = 3001;
    uint256 private constant EPIC_MAX_ID = 6000;
    uint256 private constant RARE_MIN_ID = 6001;
    uint256 private constant RARE_MAX_ID = 10000;

    mapping(uint256 => uint256) private rewardsMap;
    address private nftContractAddress;
    uint256 private totalRewards;
    uint256 private totalPoints;
    uint256 private rewardRatio;

    uint256 private constant XUNICORN_WEIGHT = 6;
    uint256 private constant EXOTIC_WEIGHT = 29;
    uint256 private constant LEGENDARY_WEIGHT = 32;
    uint256 private constant EPIC_WEIGHT = 19;
    uint256 private constant RARE_WEIGHT = 13;

    constructor(address _nftContractAddress) {
        nftContractAddress = _nftContractAddress;

        rewardsMap[XUNICORN_WEIGHT] = 6;
        rewardsMap[EXOTIC_WEIGHT] = 29;
        rewardsMap[LEGENDARY_WEIGHT] = 32;
        rewardsMap[EPIC_WEIGHT] = 19;
        rewardsMap[RARE_WEIGHT] = 13;

        // Initialize totalRewards and totalPoints with small non-zero values
        totalRewards = 1 wei; // 1 wei
        totalPoints = 1;
    }

    receive() external payable {
        totalRewards += msg.value;
        rewardRatio += msg.value / totalPoints;
    }

    function addToPool() external payable {
        totalRewards += msg.value;
        rewardRatio += msg.value / totalPoints;
    }

    function registerNFT(uint256 tokenId) external {
        require(IXENNFTContract(nftContractAddress).ownerOf(tokenId) == tx.origin, "You don't own this NFT.");

        // Calculate the reward points for the NFT
        uint256 rewardPoints = getTokenWeight(tokenId);

        // Check if the NFT was previously registered to a different user
        address  previousOwner = getNFTOwner(tokenId);
        require(previousOwner != tx.origin, "You already have this NFT regestered");
        if (previousOwner != address(0) && previousOwner != tx.origin) {
            User storage previousOwnerData = users[previousOwner];
            uint256 previousRewardPoints = previousOwnerData.userPoints;
            uint256 previousRewardAmount = calculateReward(previousOwner);
            address payable previousOwnerpay = payable(previousOwner);
            // Pay the previous owner their rewards
            previousOwnerpay.transfer(previousRewardAmount);
            
            // Remove the previous owner's points
            previousOwnerData.userPoints -= previousRewardPoints;
        }
        User storage currentUserData = users[tx.origin];

        if (currentUserData.lastRewardRatio != rewardRatio && currentUserData.lastRewardRatio != 0) {
            withdrawRewards();
        }

        // Update the user's rewards, points, and last rewarded timestamp

        currentUserData.userPoints += rewardPoints;
        totalPoints += rewardPoints;
        currentUserData.lastRewardRatio = rewardRatio;

        // Update the NFT ownership
        setNFTOwner(tokenId, tx.origin);
    }

    function isNFTRegistered(uint256 tokenId) public view returns (bool) {
        NFT[] storage userNFTs = users[msg.sender].userNFTs;
        for (uint256 j = 0; j < userNFTs.length; j++) {
            if (userNFTs[j].tokenId == tokenId) {
                return true;
            }
        }
        return false;
    }

    function setNFTOwner(uint256 tokenId, address owner) private {
        require(currentHolder[tokenId] != msg.sender, "NFT already registered by the caller.");

        currentHolder[tokenId] = msg.sender;

        // Add the token ID to the user's NFTs
        users[owner].userNFTs.push(NFT(tokenId, getCategory(tokenId)));
    }

    function getNFTOwner(uint256 tokenId) private view returns (address) {
        return currentHolder[tokenId];
    }

    function getCategory(uint256 tokenId) private pure returns (string memory) {
        if (tokenId >= XUNICORN_MIN_ID && tokenId <= XUNICORN_MAX_ID) {
            return "Xunicorn";
        } else if (tokenId >= EXOTIC_MIN_ID && tokenId <= EXOTIC_MAX_ID) {
            return "Exotic";
        } else if (tokenId >= LEGENDARY_MIN_ID && tokenId <= LEGENDARY_MAX_ID) {
            return "Legendary";
        } else if (tokenId >= EPIC_MIN_ID && tokenId <= EPIC_MAX_ID) {
            return "Epic";
        } else if (tokenId >= RARE_MIN_ID && tokenId <= RARE_MAX_ID) {
            return "Rare";
        } else {
            revert("Invalid token ID.");
        }
    }

    function calculateReward(address user) public view returns (uint256) {
        User storage userData = users[user];
        uint256 lastRewardRatio = userData.lastRewardRatio;
        uint256 newRewards = rewardRatio - lastRewardRatio;

        return newRewards * userData.userPoints;
    }

    function withdrawRewards() public payable {
        User storage userData = users[msg.sender];
        require(userData.userPoints > 0, "No rewards available for withdrawal.");

        uint256 rewardAmount = calculateReward(msg.sender);
        require(rewardAmount > 0, "No new rewards available for withdrawal.");

        // Effects
        userData.userRewards += rewardAmount;
        userData.userLastRewarded = totalRewards;
        userData.lastRewardRatio = rewardRatio;

        // Interactions
        payable(msg.sender).transfer(rewardAmount);
        
    }

    function _isNFTOwner(uint256 tokenId, address owner) private view returns (bool) {
        IXENNFTContract nftContract = IXENNFTContract(nftContractAddress);
        address nftOwner = nftContract.ownerOf(tokenId);

        return nftOwner == owner;
    }

    function _categorizeNFT(uint256 tokenId) private pure returns (string memory) {
        if (tokenId >= XUNICORN_MIN_ID && tokenId <= XUNICORN_MAX_ID) {
            return "Xunicorn";
        } else if (tokenId >= EXOTIC_MIN_ID && tokenId <= EXOTIC_MAX_ID) {
            return "Exotic";
        } else if (tokenId >= LEGENDARY_MIN_ID && tokenId <= LEGENDARY_MAX_ID) {
            return "Legendary";
        } else if (tokenId >= EPIC_MIN_ID && tokenId <= EPIC_MAX_ID) {
            return "Epic";
        } else if (tokenId >= RARE_MIN_ID && tokenId <= RARE_MAX_ID) {
            return "Rare";
        } else {
            revert("Invalid NFT category");
        }
    }

    function getTokenWeight(uint256 tokenId) private pure returns (uint256) {
        if (tokenId >= XUNICORN_MIN_ID && tokenId <= XUNICORN_MAX_ID) {
            return XUNICORN_WEIGHT;
        } else if (tokenId >= EXOTIC_MIN_ID && tokenId <= EXOTIC_MAX_ID) {
            return EXOTIC_WEIGHT;
        } else if (tokenId >= LEGENDARY_MIN_ID && tokenId <= LEGENDARY_MAX_ID) {
            return LEGENDARY_WEIGHT;
        } else if (tokenId >= EPIC_MIN_ID && tokenId <= EPIC_MAX_ID) {
            return EPIC_WEIGHT;
        } else if (tokenId >= RARE_MIN_ID && tokenId <= RARE_MAX_ID) {
            return RARE_WEIGHT;
        } else {
            revert("Invalid token ID.");
        }
    }

    function getUserNFTCounts(address user) external view returns (uint256[] memory) {
        uint256[] memory nftCounts = new uint256[](5); // Array to store NFT counts for each category

        User storage userData = users[user];
        NFT[] storage userNFTs = userData.userNFTs;

        // Iterate over the user's registered NFTs and count them for each category
        for (uint256 i = 0; i < userNFTs.length; i++) {
            NFT storage nft = userNFTs[i];
            string memory category = nft.category;

            if (keccak256(bytes(category)) == keccak256(bytes("Xunicorn"))) {
                nftCounts[0]++;
            } else if (keccak256(bytes(category)) == keccak256(bytes("Exotic"))) {
                nftCounts[1]++;
            } else if (keccak256(bytes(category)) == keccak256(bytes("Legendary"))) {
                nftCounts[2]++;
            } else if (keccak256(bytes(category)) == keccak256(bytes("Epic"))) {
                nftCounts[3]++;
            } else if (keccak256(bytes(category)) == keccak256(bytes("Rare"))) {
                nftCounts[4]++;
            }
        }

        return nftCounts;
    }

    function _hasValidOwnership(address user) private view returns (bool) {
        User storage userData = users[user];
        uint256 totalPointsOwned = 0;

        for (uint256 i = 0; i < userData.userNFTs.length; i++) {
            NFT storage nft = userData.userNFTs[i];
            if (_isNFTOwner(nft.tokenId, user)) {
                totalPointsOwned += getTokenWeight(nft.tokenId);
            } else {
                return false;
            }
        }

        return totalPointsOwned == userData.userPoints;
    }
}
