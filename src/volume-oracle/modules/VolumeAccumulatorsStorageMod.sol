// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VolumeAccumulatorsStorageMod
/// @notice Diamond-style namespaced storage for Tier 1 raw volume accumulators.
///         Slot: keccak256("volumeOracle.accumulators")
library VolumeAccumulatorsStorageMod {
    struct VolumeAccumulatorsStorage {
        /// @dev poolId → cumulative token A volume
        mapping(bytes32 => uint256) cumulativeVolumeA;
        /// @dev poolId → cumulative token B volume
        mapping(bytes32 => uint256) cumulativeVolumeB;
        /// @dev poolId → cumulative buy-side volume
        mapping(bytes32 => uint256) buyVolume;
        /// @dev poolId → cumulative sell-side volume
        mapping(bytes32 => uint256) sellVolume;
        /// @dev poolId → cumulative volume delta (buy - sell), signed
        mapping(bytes32 => int256) cvd;
        /// @dev poolId → cumulative fee volume token A
        mapping(bytes32 => uint256) feeVolumeA;
        /// @dev poolId → cumulative fee volume token B
        mapping(bytes32 => uint256) feeVolumeB;
        /// @dev poolId → cumulative price * quantity (Q128 fixed-point, for VWAP numerator)
        mapping(bytes32 => uint256) cumulativePQ;
        /// @dev poolId → cumulative quantity (for VWAP denominator)
        mapping(bytes32 => uint256) cumulativeQ;
        /// @dev poolId → last update timestamp
        mapping(bytes32 => uint256) lastUpdateTimestamp;
        /// @dev poolId → last update block number
        mapping(bytes32 => uint256) lastUpdateBlock;
    }

    // keccak256("volumeOracle.accumulators")
    bytes32 internal constant STORAGE_SLOT = 0x2c5e3b1a7d4f6e8c0b9a3d5f7e1c4b6a8d0f2e4c6a8b0d2f4e6c8a0b2d4f6e;

    function layout() internal pure returns (VolumeAccumulatorsStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
