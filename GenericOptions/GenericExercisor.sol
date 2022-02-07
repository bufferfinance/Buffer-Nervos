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

import "./BufferBNBOptions.sol";
import "../Pool/BufferBNBPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author Heisenberg
 * @title Buffer BNB Bidirectional (Call and Put) Options
 * @notice Buffer BNB Options Contract
 */
contract Exercisor is
    Ownable
{
    
    // BufferBNBOptions optionsContract;

    // constructor(BufferBNBOptions _optionsContract){
    //     optionsContract = _optionsContract;
    // }

    /**
     * @notice Check if the sender can exercise an active option
     * @param optionID ID of your option
     */
    function isExercisable(uint256 optionID, BufferBNBOptions optionsContract) external view {
        address tokenOwner = optionsContract.ownerOf(optionID);
        bool isAutoExerciseTrue = optionsContract.autoExerciseStatus(tokenOwner) && msg.sender == owner();

        (IBufferOptions.State state,,,,, uint256 expiration,) = optionsContract.options(optionID);
        bool isWithinLastHalfHourOfExpiry = block.timestamp > (expiration - 30 minutes);

        require(
            (tokenOwner == msg.sender) || (isAutoExerciseTrue && isWithinLastHalfHourOfExpiry),
            "msg.sender is not eligible to exercise the option"
        );

        require(expiration >= block.timestamp, "Option has expired");
        require(state == IBufferOptions.State.Active, "Wrong state");
    }

    /**
     * @notice Unlock funds locked in the expired options
     * @param optionID ID of the option
     */
    function isUnlockable(uint256 optionID, BufferBNBOptions optionsContract) external view {
        (IBufferOptions.State state,,,,, uint256 expiration,) = optionsContract.options(optionID);
        require(
            expiration < block.timestamp,
            "Option has not expired yet"
        );
        require(state == IBufferOptions.State.Active, "Option is not active");
    }

    /**
     * @notice Sends profits in BNB from the BNB pool to an option holder's address
     * @param optionID A specific option contract id
     */
    function calculateProfit(uint256 optionID, BufferBNBOptions optionsContract) external view returns (uint256 profit) {
        (
            ,
            uint256 strike,
            uint256 amount,
            uint256 lockedAmount,
            ,
            ,
            IBufferOptions.OptionType optionType
        ) = optionsContract.options(optionID);

        (, int256 latestPrice, , , ) = optionsContract.priceProvider().latestRoundData();
        uint256 currentPrice = uint256(latestPrice);

        if (optionType == IBufferOptions.OptionType.Call) {
            require(strike <= currentPrice, "Current price is too low");
            profit =
                ((currentPrice - strike) * amount) /
                currentPrice;
        } else {
            require(strike >= currentPrice, "Current price is too high");
            profit =
                ((strike - currentPrice) * amount) /
                currentPrice;
        }
        if (profit > lockedAmount) profit = lockedAmount;
    }

}
