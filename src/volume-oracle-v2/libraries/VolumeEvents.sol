// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VolumeEvents
/// @notice Event definitions emitted by the Volume Oracle system.
library VolumeEvents {
    /// @notice Emitted on every swap accumulation
    event VolumeAccumulated(
        bytes32 indexed poolId,
        uint256 amountA,
        uint256 amountB,
        bool isBuy,
        uint256 price,
        uint256 timestamp
    );

    /// @notice Emitted when a volume z-score breakout is detected
    event BreakoutDetected(bytes32 indexed poolId, int256 zScore, uint256 volume, uint256 timestamp);

    /// @notice Emitted when a CUSUM regime change is detected
    event RegimeChangeDetected(bytes32 indexed poolId, uint256 cusum, uint256 reference, uint256 timestamp);

    /// @notice Emitted when a protocol facet is registered or updated
    event ProtocolFacetRegistered(bytes2 indexed protocolFlags, address facet);
}
