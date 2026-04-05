// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenA.sol";
import "./TokenB.sol";
import "./LPToken.sol";

contract AMM {
    TokenA public tokenA;
    TokenB public tokenB;
    LPToken public lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed user, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed user, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = TokenA(_tokenA);
        tokenB = TokenB(_tokenB);
        lpToken = new LPToken();
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        require(amountA > 0 && amountB > 0, "zero amounts");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 shares;
        if (lpToken.totalSupply() == 0) {
            shares = sqrt(amountA * amountB);
        } else {
            shares = min(
                (amountA * lpToken.totalSupply()) / reserveA,
                (amountB * lpToken.totalSupply()) / reserveB
            );
        }

        require(shares > 0, "zero shares");

        reserveA += amountA;
        reserveB += amountB;

        lpToken.mint(msg.sender, shares);

        emit LiquidityAdded(msg.sender, amountA, amountB, shares);
    }

    function removeLiquidity(uint256 lpAmount) external {
        require(lpAmount > 0, "zero lp");

        uint256 totalLP = lpToken.totalSupply();
        require(totalLP > 0, "no lp supply");

        uint256 amountA = (lpAmount * reserveA) / totalLP;
        uint256 amountB = (lpAmount * reserveB) / totalLP;

        require(amountA > 0 && amountB > 0, "zero out");

        lpToken.burn(msg.sender, lpAmount);

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256)
    {
        require(amountIn > 0, "zero in");
        require(reserveIn > 0 && reserveOut > 0, "no liquidity");

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;

        return numerator / denominator;
    }

    function swapAForB(uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        tokenA.transferFrom(msg.sender, address(this), amountIn);
        amountOut = getAmountOut(amountIn, reserveA, reserveB);
        require(amountOut >= minAmountOut, "slippage");

        reserveA += amountIn;
        reserveB -= amountOut;

        tokenB.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, address(tokenA), amountIn, address(tokenB), amountOut);
    }

    function swapBForA(uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut) {
        tokenB.transferFrom(msg.sender, address(this), amountIn);
        amountOut = getAmountOut(amountIn, reserveB, reserveA);
        require(amountOut >= minAmountOut, "slippage");

        reserveB += amountIn;
        reserveA -= amountOut;

        tokenA.transfer(msg.sender, amountOut);

        emit Swap(msg.sender, address(tokenB), amountIn, address(tokenA), amountOut);
    }

    function getK() external view returns (uint256) {
        return reserveA * reserveB;
    }
}