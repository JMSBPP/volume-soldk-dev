// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VolumeEpochStorageMod
/// @notice Diamond-style namespaced storage for time-windowed epoch accumulators.
///         Slot: keccak256("volumeOracle.epoch")
library VolumeEpochStorageMod {
    struct EpochState {
        uint256 volumeA;
        uint256 volumeB;
        int256 cvd;
        uint256 vwapNumerator;
        uint256 vwapDenominator;
        int256 obv;
        int256 forceIndex;
    }

    struct VolumeEpochStorage {
        /// @dev poolId → epoch length in seconds
        mapping(bytes32 => uint256) epochLength;
        /// @dev poolId → current epoch ID
        mapping(bytes32 => uint256) currentEpochId;
        /// @dev poolId → epochId → epoch state snapshot
        mapping(bytes32 => mapping(uint256 => EpochState)) epochStates;
        /// @dev poolId → epoch start timestamp
        mapping(bytes32 => uint256) epochStartTimestamp;
    }

    // keccak256("volumeOracle.epoch")
    bytes32 internal constant STORAGE_SLOT = 0x4e7a5c3b9f2d6e8a0c1b3d5f7e9a0b2c4d6e8f0a1b3c5d7e9f0a2b4c6d8e0f;

    function layout() internal pure returns (VolumeEpochStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
