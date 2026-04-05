// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Counter.sol";

contract MyTokenTest is Test {
    MyToken token;

    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);

    function setUp() public {
        token = new MyToken();

        token.mint(alice, 1000 ether);
        token.mint(bob, 500 ether);
    }

    // -------------------------
    // UNIT TESTS
    // -------------------------

    function testName() public view {
        assertEq(token.name(), "MyToken");
    }

    function testSymbol() public view {
        assertEq(token.symbol(), "MTK");
    }

    function testDecimals() public view {
        assertEq(token.decimals(), 18);
    }

    function testMint() public {
        uint before = token.totalSupply();

        token.mint(charlie, 100 ether);

        assertEq(token.balanceOf(charlie), 100 ether);
        assertEq(token.totalSupply(), before + 100 ether);
    }

    function testTransfer() public {
        vm.prank(alice);
        token.transfer(bob, 100 ether);

        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 600 ether);
    }

    function testRevertTransferInsufficientBalance() public {
        vm.prank(charlie);
        vm.expectRevert("Not enough balance");
        token.transfer(bob, 1 ether);
    }

    function testApprove() public {
        vm.prank(alice);
        token.approve(bob, 300 ether);

        assertEq(token.allowance(alice, bob), 300 ether);
    }

    function testTransferFrom() public {
        vm.prank(alice);
        token.approve(bob, 200 ether);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 150 ether);

        assertEq(token.balanceOf(alice), 850 ether);
        assertEq(token.balanceOf(charlie), 150 ether);
    }

    function testRevertTransferFromWithoutApproval() public {
        vm.prank(bob);
        vm.expectRevert("Allowance exceeded");
        token.transferFrom(alice, charlie, 100 ether);
    }

    function testRevertTransferFromAboveAllowance() public {
        vm.prank(alice);
        token.approve(bob, 50 ether);

        vm.prank(bob);
        vm.expectRevert("Allowance exceeded");
        token.transferFrom(alice, charlie, 100 ether);
    }

    function testTransferZeroAmount() public {
        vm.prank(alice);
        token.transfer(bob, 0);

        assertEq(token.balanceOf(alice), 1000 ether);
        assertEq(token.balanceOf(bob), 500 ether);
    }

    function testApproveZeroAmount() public {
        vm.prank(alice);
        token.approve(bob, 0);

        assertEq(token.allowance(alice, bob), 0);
    }

    // -------------------------
    // FUZZ TEST
    // -------------------------

    function testFuzzTransfer(uint256 amount) public {
        vm.assume(amount > 0 && amount <= token.balanceOf(alice));

        vm.prank(alice);
        token.transfer(bob, amount);

        assertTrue(token.balanceOf(bob) >= 500 ether);
    }

    // -------------------------
    // INVARIANT TESTS (простые)
    // -------------------------

    function invariant_totalSupplyPositive() public view {
        assertTrue(token.totalSupply() > 0);
    }

    function invariant_balanceNotExceedSupply() public view {
        assertTrue(token.balanceOf(alice) <= token.totalSupply());
        assertTrue(token.balanceOf(bob) <= token.totalSupply());
    }
}