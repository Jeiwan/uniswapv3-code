// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import "forge-std/Test.sol";

import "../../src/lib/Oracle.sol";

contract OracleTest is Test {
    using Oracle for Oracle.Observation[65535];

    int24 tick;
    uint16 index;
    uint16 cardinality = 1;
    uint16 cardinalityNext = 1;
    Oracle.Observation[65535] oracle;

    function testObserveSingleAtCurrentTime() public {
        initialize(5, 2);

        int56 tickCumulative = observeSingle(0);
        assertEq(tickCumulative, 0);
    }

    function testObserveSingleInPastOLD() public {
        initialize(5, 2);
        vm.warp(8);

        // not earlier than secondsAgo
        vm.expectRevert(bytes("OLD"));
        observeSingle(4);
    }

    function testObserveSingleInPast() public {
        initialize(5, 2);
        vm.warp(8);

        // at secondsAgo
        int56 tickCumulative = observeSingle(3);
        assertEq(tickCumulative, 0);

        // counterfactual in past
        tickCumulative = observeSingle(1);
        assertEq(tickCumulative, 4);

        // counterfactual now
        tickCumulative = observeSingle(0);
        assertEq(tickCumulative, 6);
    }

    function testObserveSingleTwoObservations() public {
        // exact
        initialize(5, -5);
        grow(2);

        vm.warp(9);
        write(1);

        int56 tickCumulative = observeSingle(0);
        assertEq(tickCumulative, -20);

        // counterfactual
        vm.warp(16);
        tickCumulative = observeSingle(0);
        assertEq(tickCumulative, -13);

        // exactly on first observation
        tickCumulative = observeSingle(11);
        assertEq(tickCumulative, 0);

        // between first and second
        tickCumulative = observeSingle(9);
        assertEq(tickCumulative, -10);
    }

    function testObserveSingleTwoObservationsReverseOrder() public {
        // exact
        initialize(5, -5);
        grow(2);

        vm.warp(9);
        write(1);

        vm.warp(12);
        write(-5);

        int56 tickCumulative = observeSingle(0);
        assertEq(tickCumulative, -17);

        // counterfactual
        vm.warp(19);
        tickCumulative = observeSingle(0);
        assertEq(tickCumulative, -52);

        // exactly on first observation
        tickCumulative = observeSingle(10);
        assertEq(tickCumulative, -20);

        // between first and second
        tickCumulative = observeSingle(9);
        assertEq(tickCumulative, -19);
    }

    function testObserve() public {
        initialize(5, 2);
        grow(4);

        vm.warp(18);
        write(6);

        vm.warp(23);

        uint32[] memory secondsAgos = new uint32[](6);
        secondsAgos[0] = 0;
        secondsAgos[1] = 3;
        secondsAgos[2] = 8;
        secondsAgos[3] = 13;
        secondsAgos[4] = 15;
        secondsAgos[5] = 18;

        int56[] memory tickCumulatives = observe(secondsAgos);
        assertEq(tickCumulatives[0], 56);
        assertEq(tickCumulatives[1], 38);
        assertEq(tickCumulatives[2], 20);
        assertEq(tickCumulatives[3], 10);
        assertEq(tickCumulatives[4], 6);
        assertEq(tickCumulatives[5], 0);
    }

    ////////////////////////////////////////////////////////////////////////////
    //
    // INTERNAL
    //
    ////////////////////////////////////////////////////////////////////////////
    function initialize(uint32 time, int24 tick_) internal {
        vm.warp(time);

        oracle[0] = Oracle.Observation({
            timestamp: blockTimestamp(),
            tickCumulative: 0,
            initialized: true
        });

        tick = tick_;
    }

    function observeSingle(uint32 secondsAgo)
        internal
        view
        returns (int56 tickCumulative)
    {
        tickCumulative = oracle.observeSingle(
            blockTimestamp(),
            secondsAgo,
            tick,
            index,
            cardinality
        );
    }

    function observe(uint32[] memory secondsAgos)
        internal
        view
        returns (int56[] memory tickCumulatives)
    {
        tickCumulatives = oracle.observe(
            blockTimestamp(),
            secondsAgos,
            tick,
            index,
            cardinality
        );
    }

    function grow(uint16 next) internal {
        cardinalityNext = oracle.grow(cardinality, next);
    }

    function write(int24 tick_) internal {
        (index, cardinality) = oracle.write(
            index,
            blockTimestamp(),
            tick,
            cardinality,
            cardinalityNext
        );
        tick = tick_;
    }

    function blockTimestamp() internal view returns (uint32 timestamp) {
        timestamp = uint32(block.timestamp);
    }
}
