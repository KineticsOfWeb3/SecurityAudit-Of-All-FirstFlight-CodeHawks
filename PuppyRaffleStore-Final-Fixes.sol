// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "lib/base64/base64.sol";

/// @title PuppyRaffle
/// @notice A raffle system for minting puppy NFTs.
contract PuppyRaffle is ERC721, Ownable {
    using Address for address payable;

    uint256 public immutable entranceFee;
    address[] public players; // List of active players
    uint256 public raffleDuration; // Duration of the raffle
    uint256 public raffleStartTime; // Start time of the current raffle
    address public previousWinner; // Address of the previous winner

    address public feeAddress; // Address to receive fees
    uint64 public totalFees = 0; // Tracks total fees collected

    mapping(uint256 => uint256) public tokenIdToRarity; // Rarity mapping
    mapping(uint256 => string) public rarityToUri; // URI mapping for rarity
    mapping(uint256 => string) public rarityToName; // Name mapping for rarity

    // Rarity levels
    uint256 public constant COMMON_RARITY = 70;
    uint256 public constant RARE_RARITY = 25;
    uint256 public constant LEGENDARY_RARITY = 5;

    // Events
    event RaffleEnter(address[] newPlayers);
    event RaffleRefunded(address player);
    event FeeAddressChanged(address newFeeAddress);

    constructor(uint256 _entranceFee, address _feeAddress, uint256 _raffleDuration)
        ERC721("Puppy Raffle", "PR")
    {
        require(_feeAddress != address(0), "Invalid fee address"); // Validate fee address
        entranceFee = _entranceFee;
        feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;
        raffleStartTime = block.timestamp;

        rarityToUri[COMMON_RARITY] = "ipfs://common-uri";
        rarityToUri[RARE_RARITY] = "ipfs://rare-uri";
        rarityToUri[LEGENDARY_RARITY] = "ipfs://legendary-uri";

        rarityToName[COMMON_RARITY] = "common";
        rarityToName[RARE_RARITY] = "rare";
        rarityToName[LEGENDARY_RARITY] = "legendary";
    }

    /// @notice Enter the raffle with a list of players.
    /// @param newPlayers List of addresses to participate.
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "Incorrect payment");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            require(!_isDuplicate(newPlayers[i]), "Duplicate player not allowed");
            players.push(newPlayers[i]);
        }
        emit RaffleEnter(newPlayers);
    }

    /// @dev Check for duplicate addresses.
    function _isDuplicate(address player) internal view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return true;
            }
        }
        return false;
    }

    /// @notice Refund a player from the raffle.
    /// @param playerIndex The index of the player to refund.
    function refund(uint256 playerIndex) public {
        require(playerIndex < players.length, "Invalid player index");
        address player = players[playerIndex];
        require(player == msg.sender, "Only player can refund");
        require(player != address(0), "Player already refunded");

        payable(msg.sender).sendValue(entranceFee);
        players[playerIndex] = address(0); // Mark refunded player as inactive
        emit RaffleRefunded(player);
    }

    /// @notice Select a winner and reset the raffle.
    function selectWinner() external {
        require(block.timestamp >= raffleStartTime + raffleDuration, "Raffle ongoing");
        require(players.length >= 4, "Insufficient players");

        uint256 winnerIndex = _generateRandomNumber() % players.length;
        address winner = players[winnerIndex];
        require(winner != address(0), "Winner address invalid");

        uint256 totalCollected = entranceFee * players.length;
        uint256 prizePool = (totalCollected * 80) / 100;
        uint256 fee = (totalCollected * 20) / 100;

        totalFees += uint64(fee);
        previousWinner = winner;

        uint256 tokenId = totalSupply();
        _assignRarity(tokenId);

        delete players; // Reset players for the next raffle
        raffleStartTime = block.timestamp;

        payable(winner).sendValue(prizePool); // Send prize to winner
        _safeMint(winner, tokenId); // Mint NFT to winner
    }

    /// @dev Assign rarity to the token being minted.
    function _assignRarity(uint256 tokenId) internal {
        uint256 rarity = _generateRandomNumber() % 100;
        if (rarity < COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity < COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }
    }

    /// @dev Generate a pseudo-random number.
    function _generateRandomNumber() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, players)));
    }

    /// @notice Withdraw accumulated fees to the fee address.
    function withdrawFees() external onlyOwner {
        require(address(this).balance >= totalFees, "Fees still locked in raffle");
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        payable(feeAddress).sendValue(feesToWithdraw);
    }

    /// @notice Update the fee address.
    /// @param newFeeAddress The new address to receive fees.
    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        require(newFeeAddress != address(0), "Invalid fee address");
        feeAddress = newFeeAddress;
        emit FeeAddressChanged(newFeeAddress);
    }
}

