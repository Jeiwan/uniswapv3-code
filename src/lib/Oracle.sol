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

    function write(
        Observation[65535] storage self,
        uint16 index,
        uint32 timestamp,
        int24 tick,
        uint16 cardinality
    ) internal returns (uint16 indexUpdated) {
        Observation memory last = self[index];

        if (last.timestamp == timestamp) return index;

        indexUpdated = (index + 1) % cardinality;
        self[indexUpdated] = transform(last, timestamp, tick);
    }

    function transform(
        Observation memory last,
        uint32 timestamp,
        int24 tick
    ) internal pure returns (Observation memory) {
        uint56 delta = timestamp - last.timestamp;

        return
            Observation({
                timestamp: timestamp,
                tickCumulative: last.tickCumulative +
                    int56(tick) *
                    int56(delta),
                initialized: true
            });
    }
}
