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

import "../Pool/BufferBNBPool.sol";
import "./OptionConfig.sol";
import "./FeeCalculator.sol";
import "./Exercisor.sol";

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
    OptionConfig public config;
    FeeCalculator public feeCalculator;
    Exercisor public exerciseContract;

    /**
     * @param pp The address of ChainLink BNB/USD price feed contract
     */
    constructor(
        AggregatorV3Interface pp,
        BufferBNBPool _pool,
        OptionConfig _config,
        FeeCalculator _feeCalculator,
        Exercisor _exerciseContract
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
        require(
            optionType == OptionType.Call || optionType == OptionType.Put,
            "Wrong option type"
        );
        if (optionType == OptionType.Call) {
            require(
                permittedTradingType == PermittedTradingType.All ||
                    permittedTradingType == PermittedTradingType.OnlyCall,
                "Owner has disabled option trading for call options"
            );
        } else if (optionType == OptionType.Put) {
            require(
                permittedTradingType == PermittedTradingType.All ||
                    permittedTradingType == PermittedTradingType.OnlyPut,
                "Owner has disabled option trading for put options"
            );
        }
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

        optionID = createOptionFor(msg.sender);
        options[optionID] = option;

        uint256 stakingAmount = distributeSettlementFee(
            settlementFee,
            referrer
        );

        pool.lock{value: option.premium}(optionID, option.lockedAmount);

        emit Create(optionID, msg.sender, stakingAmount, totalFee);
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
            }
            payable(owner()).transfer(adminFee);
        }
    }

    /**
     * @dev See EIP-165: ERC-165 Standard Interface Detection
     * https://eips.ethereum.org/EIPS/eip-165
     **/
    function createOptionFor(address holder) internal returns (uint256 id) {
        id = nextTokenId++;
        _safeMint(holder, id);
    }

    /**
     * @dev Template code provided by OpenZepplin Code Wizard
     */
    function _baseURI() internal pure override returns (string memory) {
        return "https://buffer.finance";
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

    function setAutoExerciseStatus(bool status) public {
        autoExerciseStatus[msg.sender] = status;
        emit AutoExerciseStatusChange(msg.sender, status);
    }
}
