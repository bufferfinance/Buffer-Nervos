pragma solidity ^0.8.0;

/**
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Buffer
 * Copyright (C) 2020 Buffer Protocol
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import "../../Pool/BufferBNBPool.sol";
import "./BNBOptionConfig.sol";
import "./BNBFeeCalculator.sol";
import "./BNBExercisor.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * @author Heisenberg
 * @title Buffer BNB Bidirectional (Call and Put) Options
 * @notice Buffer BNB Options Contract
 */
contract BufferBNBOptions is
    IBufferOptions,
    Ownable,
    ERC721URIStorage,
    ERC721Enumerable,
    ERC721Burnable,
    AccessControl,
    ReentrancyGuard
{
    uint256 public nextTokenId = 0;

    mapping(uint256 => Option) public options;
    uint256 internal constant PRICE_DECIMALS = 1e8;
    uint256 internal contractCreationTimestamp;
    AggregatorV3Interface public priceProvider;
    BufferBNBPool public pool;
    BNBOptionConfig public config;
    BNBFeeCalculator public feeCalculator;
    BNBExercisor public exerciseContract;

    event PayReferralFee(address indexed referrer, uint256 amount);
    event PayAdminFee(address indexed owner, uint256 amount);

    /**
     * @param pp The address of ChainLink BNB/USD price feed contract
     */
    constructor(
        AggregatorV3Interface pp,
        BufferBNBPool _pool,
        BNBOptionConfig _config,
        BNBFeeCalculator _feeCalculator,
        BNBExercisor _exerciseContract
    ) ERC721("Buffer", "BFR") {
        pool = _pool;
        config = _config;
        feeCalculator = _feeCalculator;
        exerciseContract = _exerciseContract;
        priceProvider = pp;
        contractCreationTimestamp = block.timestamp;
    }

    /**
     * @notice Creates a new option
     * @param period Option period in seconds (1 days <= period <= 90 days)
     * @param amount Option amount
     * @param strike Strike price of the option
     * @param optionType Call or Put option type
     * @return optionID Created option's ID
     */
    function create(
        uint256 period,
        uint256 amount,
        uint256 strike,
        OptionType optionType,
        address referrer,
        string memory metadata
    ) external payable nonReentrant returns (uint256 optionID) {
        (
            uint256 totalFee,
            uint256 settlementFee,
            uint256 strikeFee,

        ) = feeCalculator.fees(
                period,
                amount,
                strike,
                optionType,
                priceProvider,
                config
            );

        config.checkParams(
            optionType,
            period,
            amount,
            strikeFee,
            totalFee,
            msg.value
        );

        if (msg.value > totalFee) {
            payable(msg.sender).transfer(msg.value - totalFee);
        }

        Option memory option = Option(
            State.Active,
            // impliedVolRate = 12500;
            strike,
            amount,
            ((amount - strikeFee * config.optionCollateralizationRatio()) /
                100) + strikeFee, // lockedAmount
            totalFee - settlementFee,
            block.timestamp + period,
            optionType
        );

        optionID = createOptionFor(msg.sender, metadata);
        options[optionID] = option;

        uint256 stakingAmount = distributeSettlementFee(
            settlementFee,
            referrer
        );

        pool.lock{value: option.premium}(optionID, option.lockedAmount);

        // Set User's Auto Close Status to True by default
        // Check if this is the user's first option from this contract
        if (!hasUserBoughtFirstOption[msg.sender]) {
            // if yes then set the auto close for the user to True
            if (!autoExerciseStatus[msg.sender]) {
                autoExerciseStatus[msg.sender] = true;
                emit AutoExerciseStatusChange(msg.sender, true);
            }
            hasUserBoughtFirstOption[msg.sender] = true;
        }

        emit Create(optionID, msg.sender, stakingAmount, totalFee, metadata);
    }

    function distributeSettlementFee(uint256 settlementFee, address referrer)
        internal
        returns (uint256 stakingAmount)
    {
        stakingAmount = ((settlementFee * config.stakingFeePercentage()) / 100);

        // Incase the stakingAmount is 0
        if (stakingAmount > 0) {
            config.settlementFeeRecipient().sendProfit{value: stakingAmount}();
        }

        uint256 adminFee = settlementFee - stakingAmount;

        if (adminFee > 0) {
            if (
                config.referralRewardPercentage() > 0 &&
                referrer != owner() &&
                referrer != msg.sender
            ) {
                uint256 referralReward = (adminFee *
                    config.referralRewardPercentage()) / 100;
                adminFee = adminFee - referralReward;
                payable(referrer).transfer(referralReward);
                emit PayReferralFee(referrer, referralReward);
            }
            payable(owner()).transfer(adminFee);
            emit PayAdminFee(owner(), adminFee);
        }
    }

    /**
     * @dev See EIP-165: ERC-165 Standard Interface Detection
     * https://eips.ethereum.org/EIPS/eip-165
     **/
    function createOptionFor(address holder, string memory metadata)
        internal
        returns (uint256 id)
    {
        id = nextTokenId++;
        _safeMint(holder, id);
        _setTokenURI(id, metadata);
    }

    /**
     * @dev Template code provided by OpenZepplin Code Wizard
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        override
    {
        return super._setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev Template code provided by OpenZepplin Code Wizard
     */
    function _baseURI() internal pure override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/";
    }

    /**
     * @dev Template code provided by OpenZepplin Code Wizard
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Template code provided by OpenZepplin Code Wizard
     */
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        return super._burn(tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @notice Exercises an active option
     * @param optionID ID of your option
     */
    function exercise(uint256 optionID, BufferBNBOptions optionsContract)
        external
    {
        require(
            _exists(optionID),
            "ERC721: operator query for nonexistent token"
        );
        Option storage option = options[optionID];

        exerciseContract.isExercisable(optionID, optionsContract);

        option.state = IBufferOptions.State.Exercised;
        uint256 profit = payProfit(optionID, optionsContract);

        // Burn the option
        _burn(optionID);

        emit Exercise(optionID, profit);
    }

    /**
     * @notice Unlock funds locked in the expired options
     * @param optionID ID of the option
     */
    function unlock(uint256 optionID, BufferBNBOptions optionsContract) public {
        Option storage option = options[optionID];

        exerciseContract.isUnlockable(optionID, optionsContract);

        option.state = IBufferOptions.State.Expired;
        pool.unlock(optionID);

        // Burn the option
        _burn(optionID);

        emit Expire(optionID, option.premium);
    }

    /**
     * @notice Sends profits in BNB from the BNB pool to an option holder's address
     * @param optionID A specific option contract id
     */
    function payProfit(uint256 optionID, BufferBNBOptions optionsContract)
        internal
        returns (uint256 profit)
    {
        profit = exerciseContract.calculateProfit(optionID, optionsContract);
        pool.send(optionID, payable(optionsContract.ownerOf(optionID)), profit);
    }

    /**
     * Exercise Approval
     */

    // Mapping from owner to exerciser approvals
    mapping(address => bool) public autoExerciseStatus;
    mapping(address => bool) public hasUserBoughtFirstOption;

    function setAutoExerciseStatus(bool status) public {
        autoExerciseStatus[msg.sender] = status;
        emit AutoExerciseStatusChange(msg.sender, status);
    }
}
