// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
}

contract ForkTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function testReadUSDCTotalSupply() public view {
        uint256 supply = IERC20(USDC).totalSupply();
        assertTrue(supply > 0);
    }

    function testRollFork() public {
        uint256 beforeBlock = block.number;
        vm.rollFork(beforeBlock - 5);
        uint256 afterBlock = block.number;

        console.log("Before block:", beforeBlock);
        console.log("After block :", afterBlock);

        assertEq(afterBlock, beforeBlock - 5);
    }
}
