// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/TokenA.sol";
import "../src/TokenB.sol";
import "../src/LPToken.sol";

contract AMMTest is Test {
    TokenA tokenA;
    TokenB tokenB;
    AMM amm;

    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        tokenA = new TokenA(1_000_000 ether);
        tokenB = new TokenB(1_000_000 ether);
        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.transfer(alice, 10_000 ether);
        tokenB.transfer(alice, 10_000 ether);
        tokenA.transfer(bob, 10_000 ether);
        tokenB.transfer(bob, 10_000 ether);

        vm.startPrank(alice);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }

    function addInitialLiquidity() internal {
        vm.prank(alice);
        amm.addLiquidity(1000 ether, 1000 ether);
    }

    function testAddLiquidityFirstProvider() public {
        addInitialLiquidity();
        assertEq(amm.reserveA(), 1000 ether);
        assertEq(amm.reserveB(), 1000 ether);
    }

    function testAddLiquiditySubsequentProvider() public {
        addInitialLiquidity();

        vm.prank(bob);
        amm.addLiquidity(500 ether, 500 ether);

        assertEq(amm.reserveA(), 1500 ether);
        assertEq(amm.reserveB(), 1500 ether);
    }

    function testLPTokenMinted() public {
        addInitialLiquidity();
        LPToken lp = amm.lpToken();
        assertTrue(lp.balanceOf(alice) > 0);
    }

    function testRemoveLiquidityPartial() public {
        addInitialLiquidity();
        LPToken lp = amm.lpToken();
        uint256 half = lp.balanceOf(alice) / 2;

        vm.prank(alice);
        amm.removeLiquidity(half);

        assertTrue(amm.reserveA() < 1000 ether);
        assertTrue(amm.reserveB() < 1000 ether);
    }

    function testRemoveLiquidityFull() public {
        addInitialLiquidity();
        LPToken lp = amm.lpToken();
        uint256 allLp = lp.balanceOf(alice);

        vm.prank(alice);
        amm.removeLiquidity(allLp);

        assertEq(amm.reserveA(), 0);
        assertEq(amm.reserveB(), 0);
    }

    function testSwapAForB() public {
        addInitialLiquidity();

        vm.prank(bob);
        uint256 out = amm.swapAForB(100 ether, 1);

        assertTrue(out > 0);
    }

    function testSwapBForA() public {
        addInitialLiquidity();

        vm.prank(bob);
        uint256 out = amm.swapBForA(100 ether, 1);

        assertTrue(out > 0);
    }

    function testGetAmountOut() public view {
        uint256 out = amm.getAmountOut(100 ether, 1000 ether, 1000 ether);
        assertTrue(out > 0);
    }

    function testKNonDecreasingAfterSwap() public {
        addInitialLiquidity();
        uint256 beforeK = amm.getK();

        vm.prank(bob);
        amm.swapAForB(100 ether, 1);

        uint256 afterK = amm.getK();
        assertTrue(afterK >= beforeK);
    }

    function testRevertSlippageAForB() public {
        addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert("slippage");
        amm.swapAForB(100 ether, 1000 ether);
    }

    function testRevertSlippageBForA() public {
        addInitialLiquidity();

        vm.prank(bob);
        vm.expectRevert("slippage");
        amm.swapBForA(100 ether, 1000 ether);
    }

    function testRevertZeroLiquidityAdd() public {
        vm.prank(alice);
        vm.expectRevert("zero amounts");
        amm.addLiquidity(0, 100 ether);
    }

    function testRevertSingleSidedLiquidity() public {
        vm.prank(alice);
        vm.expectRevert("zero amounts");
        amm.addLiquidity(100 ether, 0);
    }

    function testLargeSwapPriceImpact() public {
        addInitialLiquidity();

        vm.prank(bob);
        uint256 out = amm.swapAForB(900 ether, 1);

        assertTrue(out < 900 ether);
    }

    function testRevertRemoveZeroLP() public {
        addInitialLiquidity();

        vm.prank(alice);
        vm.expectRevert("zero lp");
        amm.removeLiquidity(0);
    }

    function testFuzzSwapAForB(uint96 amount) public {
        addInitialLiquidity();

        uint256 amountIn = bound(uint256(amount), 1 ether, 200 ether);

        vm.prank(bob);
        uint256 out = amm.swapAForB(amountIn, 1);

        assertTrue(out > 0);
    }
}
