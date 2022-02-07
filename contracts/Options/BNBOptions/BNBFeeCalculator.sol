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

import "./BNBOptionConfig.sol";

/**
 * @author Heisenberg
 * @title Buffer BNB Bidirectional (Call and Put) Options
 * @notice Buffer BNB Options Contract
 */
contract BNBFeeCalculator {
    uint256 internal constant PRICE_DECIMALS = 1e8;

    /**
     * @notice Used for getting the actual options prices
     * @param period Option period in seconds (1 days <= period <= 4 weeks)
     * @param amount Option amount
     * @param strike Strike price of the option
     * @return total Total price to be paid
     * @return settlementFee Amount to be distributed to the Buffer token holders
     * @return strikeFee Amount that covers the price difference in the ITM options
     * @return periodFee Option period fee amount
     */
    function fees(
        uint256 period,
        uint256 amount,
        uint256 strike,
        IBufferOptions.OptionType optionType,
        AggregatorV3Interface priceProvider,
        BNBOptionConfig config
    )
        public
        view
        returns (
            uint256 total,
            uint256 settlementFee,
            uint256 strikeFee,
            uint256 periodFee
        )
    {
        (, int256 latestPrice, , , ) = priceProvider.latestRoundData();
        uint256 currentPrice = uint256(latestPrice);
        settlementFee = getSettlementFee(amount, config);
        periodFee = getPeriodFee(
            amount,
            period,
            strike,
            currentPrice,
            optionType,
            config
        );
        strikeFee = getStrikeFee(amount, strike, currentPrice, optionType);
        total = periodFee + strikeFee + settlementFee;
    }

    /**
     * @notice Calculates periodFee
     * @param amount Option amount
     * @param period Option period in seconds (1 days <= period <= 4 weeks)
     * @param strike Strike price of the option
     * @param currentPrice Current price of BNB
     * @return fee Period fee amount
     *
     * amount < 1e30        |
     * impliedVolRate < 1e10| => amount * impliedVolRate * strike < 1e60 < 2^uint256
     * strike < 1e20 ($1T)  |
     *
     * in case amount * impliedVolRate * strike >= 2^256
     * transaction will be reverted by the SafeMath
     */
    function getPeriodFee(
        uint256 amount,
        uint256 period,
        uint256 strike,
        uint256 currentPrice,
        IBufferOptions.OptionType optionType,
        BNBOptionConfig config
    ) internal view returns (uint256 fee) {
        if (optionType == IBufferOptions.OptionType.Put)
            return
                (amount * sqrt(period) * config.impliedVolRate() * strike) /
                (currentPrice * PRICE_DECIMALS);
        else
            return
                (amount *
                    sqrt(period) *
                    config.impliedVolRate() *
                    currentPrice) / (strike * PRICE_DECIMALS);
    }

    /**
     * @notice Calculates strikeFee
     * @param amount Option amount
     * @param strike Strike price of the option
     * @param currentPrice Current price of BNB
     * @return fee Strike fee amount
     */
    function getStrikeFee(
        uint256 amount,
        uint256 strike,
        uint256 currentPrice,
        IBufferOptions.OptionType optionType
    ) internal pure returns (uint256 fee) {
        if (
            strike > currentPrice && optionType == IBufferOptions.OptionType.Put
        ) return ((strike - currentPrice) * amount) / currentPrice;
        if (
            strike < currentPrice &&
            optionType == IBufferOptions.OptionType.Call
        ) return ((currentPrice - strike) * amount) / currentPrice;
        return 0;
    }

    /**
     * @notice Calculates settlementFee
     * @param amount Option amount
     * @return fee Settlement fee amount
     */
    function getSettlementFee(uint256 amount, BNBOptionConfig config)
        internal
        view
        returns (uint256 fee)
    {
        return (amount * config.settlementFeePercentage()) / 100;
    }

    /**
     * @return result Square root of the number
     */
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        result = x;
        uint256 k = (x / 2) + 1;
        while (k < result) (result, k) = (k, ((x / k) + k) / 2);
    }
}
