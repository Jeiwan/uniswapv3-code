// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.14;

library Oracle {
    struct Observation {
        uint32 timestamp;
        int56 tickCumulative;
        bool initialized;
    }

    function initialize(Observation[65535] storage self, uint32 time)
        internal
        returns (uint16 cardinality)
    {
        self[0] = Observation({
            timestamp: time,
            tickCumulative: 0,
            initialized: true
        });

        cardinality = 1;
    }
}
