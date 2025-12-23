// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Corn.sol";
import "./CornDEX.sol";

error Lending__InvalidAmount();
error Lending__TransferFailed();
error Lending__UnsafePositionRatio();
error Lending__BorrowingFailed();
error Lending__RepayingFailed();
error Lending__PositionSafe();
error Lending__NotLiquidatable();
error Lending__InsufficientLiquidatorCorn();

contract Lending is Ownable {
    uint256 private constant COLLATERAL_RATIO = 120; // 120% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators

    Corn private i_corn;
    CornDEX private i_cornDEX;

    mapping(address => uint256) public s_userCollateral; // User's collateral balance
    mapping(address => uint256) public s_userBorrowed; // User's borrowed corn balance

    event CollateralAdded(address indexed user, uint256 amount, uint256 price);
    event CollateralWithdrawn(address indexed user, uint256 amount, uint256 price);
    event AssetBorrowed(address indexed user, uint256 amount, uint256 price);
    event AssetRepaid(address indexed user, uint256 amount, uint256 price);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    constructor(address _cornDEX, address _corn) Ownable(msg.sender) {
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(this), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            COLLATERAL
    //////////////////////////////////////////////////////////////*/

    function addCollateral() public payable {
        if (msg.value == 0) revert Lending__InvalidAmount();

        s_userCollateral[msg.sender] += msg.value;

        emit CollateralAdded(
            msg.sender,
            msg.value,
            i_cornDEX.currentPrice()
        );
    }

    function withdrawCollateral(uint256 amount) public {
        if (amount == 0) revert Lending__InvalidAmount();
        if (s_userCollateral[msg.sender] < amount) revert Lending__InvalidAmount();

        s_userCollateral[msg.sender] -= amount;

        // Only validate if user has debt
        if (s_userBorrowed[msg.sender] > 0) {
            _validatePosition(msg.sender);
        }

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert Lending__TransferFailed();

        emit CollateralWithdrawn(
            msg.sender,
            amount,
            i_cornDEX.currentPrice()
        );
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function calculateCollateralValue(address user) public view returns (uint256) {
        // ETH * (CORN / ETH)
        return (s_userCollateral[user] * i_cornDEX.currentPrice()) / 1e18;
    }

    function _calculatePositionRatio(address user) internal view returns (uint256) {
        uint256 borrowed = s_userBorrowed[user];
        if (borrowed == 0) return type(uint256).max;

        uint256 collateralValue = calculateCollateralValue(user);

        // (collateral / debt) * 100 * 1e18
        return (collateralValue * 100 * 1e18) / borrowed;
    }

    function isLiquidatable(address user) public view returns (bool) {
        return _calculatePositionRatio(user) < (COLLATERAL_RATIO * 1e18);
    }

    function _validatePosition(address user) internal view {
        if (isLiquidatable(user)) revert Lending__UnsafePositionRatio();
    }

    /*//////////////////////////////////////////////////////////////
                            BORROW / REPAY
    //////////////////////////////////////////////////////////////*/

    function borrowCorn(uint256 borrowAmount) public {
        if (borrowAmount == 0) revert Lending__InvalidAmount();

        s_userBorrowed[msg.sender] += borrowAmount;

        _validatePosition(msg.sender);

        bool success = i_corn.transfer(msg.sender, borrowAmount);
        if (!success) revert Lending__BorrowingFailed();

        emit AssetBorrowed(
            msg.sender,
            borrowAmount,
            i_cornDEX.currentPrice()
        );
    }

    function repayCorn(uint256 repayAmount) public {
        if (repayAmount == 0) revert Lending__InvalidAmount();
        if (repayAmount > s_userBorrowed[msg.sender]) revert Lending__InvalidAmount();

        s_userBorrowed[msg.sender] -= repayAmount;

        bool success = i_corn.transferFrom(
            msg.sender,
            address(this),
            repayAmount
        );
        if (!success) revert Lending__RepayingFailed();

        emit AssetRepaid(
            msg.sender,
            repayAmount,
            i_cornDEX.currentPrice()
        );
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDATION
    //////////////////////////////////////////////////////////////*/

    function liquidate(address user) public {
        if (!isLiquidatable(user)) revert Lending__NotLiquidatable();

        uint256 userDebt = s_userBorrowed[user];
        if (i_corn.balanceOf(msg.sender) < userDebt) {
            revert Lending__InsufficientLiquidatorCorn();
        }

        // Take CORN from liquidator
        bool success = i_corn.transferFrom(
            msg.sender,
            address(this),
            userDebt
        );
        if (!success) revert Lending__RepayingFailed();

        s_userBorrowed[user] = 0;

        uint256 price = i_cornDEX.currentPrice();

        // ETH needed to cover debt
        uint256 collateralNeeded =
            (userDebt * 1e18) / price;

        // Liquidator reward
        uint256 reward =
            (collateralNeeded * LIQUIDATOR_REWARD) / 100;

        uint256 payout = collateralNeeded + reward;

        if (payout > s_userCollateral[user]) {
            payout = s_userCollateral[user];
        }

        s_userCollateral[user] -= payout;

        (bool sent, ) = msg.sender.call{value: payout}("");
        if (!sent) revert Lending__TransferFailed();

        emit Liquidation(
            user,
            msg.sender,
            payout,
            userDebt,
            price
        );
    }

    receive() external payable {}
}
