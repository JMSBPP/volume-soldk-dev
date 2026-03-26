// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IVolumeEpoch
/// @notice Interface for time-windowed volume metric accumulation with automatic resets
interface IVolumeEpoch {
    /// @notice Initialize epoch tracking for a pool
    function initializeEpochPool(bytes32 poolId, uint256 epochLength) external;

    /// @notice Get the current epoch ID for a pool
    function getCurrentEpochId(bytes32 poolId) external view returns (uint256 epochId);

    /// @notice Get epoch-scoped volume accumulators
    function getEpochVolume(bytes32 poolId, uint256 epochId)
        external
        view
        returns (uint256 volumeA, uint256 volumeB, int256 cvd);

    /// @notice Get epoch-scoped analytics snapshot
    function getEpochAnalytics(bytes32 poolId, uint256 epochId)
        external
        view
        returns (uint256 vwap, int256 obv, int256 forceIndex);

    /// @notice Check if an epoch boundary has been crossed and trigger reset
    function checkEpochBoundary(bytes32 poolId) external returns (bool crossed, uint256 newEpochId);

    // ── Events ──────────────────────────────────────────────────────

    event EpochInitialized(bytes32 indexed poolId, uint256 epochLength);
    event EpochReset(bytes32 indexed poolId, uint256 indexed oldEpochId, uint256 indexed newEpochId);
}
