pragma solidity ^0.8.0;

/**
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

interface ILiquidityPool {
    struct LockedLiquidity {
        uint256 amount;
        uint256 premium;
        bool locked;
    }

    event Profit(uint256 indexed id, uint256 amount);
    event Loss(uint256 indexed id, uint256 amount);
    event Provide(address indexed account, uint256 amount, uint256 writeAmount);
    event Withdraw(
        address indexed account,
        uint256 amount,
        uint256 writeAmount
    );

    function unlock(uint256 id) external;

    function send(
        uint256 id,
        address payable account,
        uint256 amount
    ) external;

    function totalBalance() external view returns (uint256 amount);
    // function unlockPremium(uint256 amount) external;
}

interface IBNBLiquidityPool is ILiquidityPool {
    event UpdateRevertTransfersInLockUpPeriod(
        address indexed account,
        bool value
    );

    function lock(uint256 id, uint256 amount) external payable;
}

interface IBufferOptions {
    event Create(
        uint256 indexed id,
        address indexed account,
        uint256 settlementFee,
        uint256 totalFee,
        string metadata
    );
    enum State {
        Inactive,
        Active,
        Exercised,
        Expired
    }
    enum OptionType {
        Invalid,
        Put,
        Call
    }

    struct Option {
        State state;
        uint256 strike;
        uint256 amount;
        uint256 lockedAmount;
        uint256 premium;
        uint256 expiration;
        OptionType optionType;
    }

    event Exercise(uint256 indexed id, uint256 profit);
    event Expire(uint256 indexed id, uint256 premium);
    event AutoExerciseStatusChange(address indexed account, bool status);
}

interface IOptionConfig {
    event UpdateImpliedVolatility(uint256 value);
    event UpdateSettlementFeePercentage(uint256 value);
    event UpdateSettlementFeeRecipient(address account);
    event UpdateStakingFeePercentage(uint256 value);
    event UpdateReferralRewardPercentage(uint256 value);
    event UpdateOptionCollaterizationRatio(uint256 value);
    event UpdateNFTSaleRoyaltyPercentage(uint256 value);
    event UpdateTradingPermission(PermittedTradingType permissionType);
    event UpdateOptionCreationWindow(
        uint256 startHour,
        uint256 startMinute,
        uint256 endHour,
        uint256 endMinute
    );

    struct OptionCreationWindow {
        uint256 startHour;
        uint256 startMinute;
        uint256 endHour;
        uint256 endMinute;
    }

    enum PermittedTradingType {
        All,
        OnlyPut,
        OnlyCall,
        None
    }

    enum OptionType {
        Invalid,
        Put,
        Call
    }
}

interface IBufferStaking {
    event Claim(address indexed acount, uint256 amount);
    event Profit(uint256 amount);
    event Buy(address indexed acount, uint256 amount, uint256 transferAmount);
    event Sell(address indexed acount, uint256 amount, uint256 transferAmount);
    event UpdateRevertTransfersInLockUpPeriod(
        address indexed account,
        bool value
    );

    function claimProfit() external returns (uint256 profit);

    function buy(uint256 amountOfTokens) external;

    function sell(uint256 amountOfTokens) external;

    function profitOf(address account) external view returns (uint256);
}

interface IBufferStakingBNB is IBufferStaking {
    function sendProfit() external payable;
}

interface IBufferStakingIBFR is IBufferStaking {
    function sendProfit(uint256 amount) external;
}

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
