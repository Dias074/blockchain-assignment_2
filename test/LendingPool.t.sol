// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CollateralToken.sol";
import "../src/BorrowToken.sol";
import "../src/MockPriceOracle.sol";
import "../src/LendingPool.sol";

contract LendingPoolTest is Test {
    CollateralToken collateral;
    BorrowToken debtToken;
    MockPriceOracle oracle;
    LendingPool pool;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        collateral = new CollateralToken(1_000_000 ether);
        debtToken = new BorrowToken(1_000_000 ether);
        oracle = new MockPriceOracle(1 ether); // 1 collateral = 1 borrow token
        pool = new LendingPool(address(collateral), address(debtToken), address(oracle));

        collateral.transfer(alice, 10_000 ether);
        collateral.transfer(bob, 10_000 ether);
        debtToken.transfer(address(pool), 100_000 ether);
        debtToken.transfer(alice, 10_000 ether);
        debtToken.transfer(bob, 10_000 ether);

        vm.startPrank(alice);
        collateral.approve(address(pool), type(uint256).max);
        debtToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        collateral.approve(address(pool), type(uint256).max);
        debtToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }

    function depositByAlice(uint256 amount) internal {
        vm.prank(alice);
        pool.deposit(amount);
    }

    function testDeposit() public {
        depositByAlice(1000 ether);
        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 1000 ether);
    }

    function testWithdraw() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.withdraw(200 ether);

        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 800 ether);
    }

    function testBorrowWithinLTV() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(700 ether);

        (,uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 700 ether);
    }

    function testRevertBorrowExceedingLTV() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        vm.expectRevert("exceeds ltv");
        pool.borrow(800 ether);
    }

    function testRepayPartial() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.prank(alice);
        pool.repay(200 ether);

        (,uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 300 ether);
    }

    function testRepayFull() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.prank(alice);
        pool.repay(500 ether);

        (,uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 0);
    }

    function testRevertBorrowWithoutCollateral() public {
        vm.prank(alice);
        vm.expectRevert("no collateral");
        pool.borrow(100 ether);
    }

    function testRevertWithdrawWithUnsafeHealthFactor() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(700 ether);

        vm.prank(alice);
        vm.expectRevert("health factor too low");
        pool.withdraw(500 ether);
    }

    function testInterestAccrualOverTime() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.warp(block.timestamp + 30 days);

        pool.accrueInterest(alice);

        (,uint256 borrowed,) = pool.getPosition(alice);
        assertTrue(borrowed > 500 ether);
    }

    function testLiquidationAfterPriceDrop() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(700 ether);

        oracle.setPrice(5e17); // price drops from 1.0 to 0.5

        vm.prank(bob);
        pool.liquidate(alice);

        (uint256 deposited, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(deposited, 0);
        assertEq(borrowed, 0);
    }

    function testHealthFactor() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        (, , uint256 hf) = pool.getPosition(alice);
        assertTrue(hf > 1e18);
    }

    function testRevertLiquidateHealthyPosition() public {
        depositByAlice(1000 ether);

        vm.prank(alice);
        pool.borrow(500 ether);

        vm.prank(bob);
        vm.expectRevert("position healthy");
        pool.liquidate(alice);
    }
}