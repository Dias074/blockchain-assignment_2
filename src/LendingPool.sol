// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./CollateralToken.sol";
import "./BorrowToken.sol";
import "./MockPriceOracle.sol";

contract LendingPool {
    CollateralToken public collateralToken;
    BorrowToken public borrowToken;
    MockPriceOracle public oracle;

    uint256 public constant LTV = 75; // 75%
    uint256 public constant LIQUIDATION_THRESHOLD = 100; // HF > 1 required
    uint256 public constant INTEREST_PER_SECOND = 3170979198;
    // ~10% APR scaled to 1e18 debt basis approximation

    struct Position {
        uint256 collateralDeposited;
        uint256 borrowedAmount;
        uint256 lastUpdate;
    }

    mapping(address => Position) public positions;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed user, uint256 repaidAmount);

    constructor(address _collateralToken, address _borrowToken, address _oracle) {
        collateralToken = CollateralToken(_collateralToken);
        borrowToken = BorrowToken(_borrowToken);
        oracle = MockPriceOracle(_oracle);
    }

    function accrueInterest(address user) public {
        Position storage p = positions[user];

        if (p.borrowedAmount == 0) {
            p.lastUpdate = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - p.lastUpdate;
        if (timeElapsed > 0) {
            uint256 interest = (p.borrowedAmount * INTEREST_PER_SECOND * timeElapsed) / 1e18;
            p.borrowedAmount += interest;
            p.lastUpdate = block.timestamp;
        }
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "zero deposit");

        Position storage p = positions[msg.sender];
        accrueInterest(msg.sender);

        collateralToken.transferFrom(msg.sender, address(this), amount);
        p.collateralDeposited += amount;
        if (p.lastUpdate == 0) {
            p.lastUpdate = block.timestamp;
        }

        emit Deposited(msg.sender, amount);
    }

    function maxBorrow(address user) public view returns (uint256) {
        Position memory p = positions[user];
        uint256 price = oracle.getPrice(); // 1e18 precision
        uint256 collateralValue = (p.collateralDeposited * price) / 1e18;
        return (collateralValue * LTV) / 100;
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "zero borrow");

        accrueInterest(msg.sender);
        Position storage p = positions[msg.sender];

        require(p.collateralDeposited > 0, "no collateral");
        require(p.borrowedAmount + amount <= maxBorrow(msg.sender), "exceeds ltv");

        p.borrowedAmount += amount;
        borrowToken.transfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        require(amount > 0, "zero repay");

        accrueInterest(msg.sender);
        Position storage p = positions[msg.sender];
        require(p.borrowedAmount > 0, "no debt");

        uint256 repayAmount = amount > p.borrowedAmount ? p.borrowedAmount : amount;

        borrowToken.transferFrom(msg.sender, address(this), repayAmount);
        p.borrowedAmount -= repayAmount;

        emit Repaid(msg.sender, repayAmount);
    }

    function getHealthFactor(address user) public view returns (uint256) {
        Position memory p = positions[user];
        if (p.borrowedAmount == 0) return type(uint256).max;

        uint256 price = oracle.getPrice();
        uint256 collateralValue = (p.collateralDeposited * price) / 1e18;

        return (collateralValue * 1e18) / p.borrowedAmount;
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "zero withdraw");

        accrueInterest(msg.sender);
        Position storage p = positions[msg.sender];
        require(p.collateralDeposited >= amount, "not enough collateral");

        p.collateralDeposited -= amount;

        if (p.borrowedAmount > 0) {
            require(getHealthFactor(msg.sender) > 1e18, "health factor too low");
        }

        collateralToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user) external {
        accrueInterest(user);
        Position storage p = positions[user];

        require(p.borrowedAmount > 0, "no debt");
        require(getHealthFactor(user) <= 1e18, "position healthy");

        uint256 debt = p.borrowedAmount;
        borrowToken.transferFrom(msg.sender, address(this), debt);

        uint256 collateralToSeize = p.collateralDeposited;

        p.borrowedAmount = 0;
        p.collateralDeposited = 0;

        collateralToken.transfer(msg.sender, collateralToSeize);

        emit Liquidated(msg.sender, user, debt);
    }

    function getPosition(address user)
        external
        view
        returns (uint256 deposited, uint256 borrowed, uint256 healthFactor)
    {
        Position memory p = positions[user];
        deposited = p.collateralDeposited;
        borrowed = p.borrowedAmount;
        healthFactor = getHealthFactor(user);
    }
}
