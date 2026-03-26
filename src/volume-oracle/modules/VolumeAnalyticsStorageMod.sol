// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title VolumeAnalyticsStorageMod
/// @notice Diamond-style namespaced storage for Tier 2 derived volume analytics.
///         Slot: keccak256("volumeOracle.analytics")
library VolumeAnalyticsStorageMod {
    struct VolumeAnalyticsStorage {
        /// @dev poolId → short-period EMA (e.g., 10-period)
        mapping(bytes32 => uint256) emaShort;
        /// @dev poolId → long-period EMA (e.g., 50-period)
        mapping(bytes32 => uint256) emaLong;
        /// @dev poolId → Welford online count
        mapping(bytes32 => uint256) welfordCount;
        /// @dev poolId → Welford running mean (Q128 fixed-point)
        mapping(bytes32 => int256) welfordMean;
        /// @dev poolId → Welford running M2 (sum of squared deviations)
        mapping(bytes32 => uint256) welfordM2;
        /// @dev poolId → on-balance volume (signed)
        mapping(bytes32 => int256) obv;
        /// @dev poolId → volume-price trend (signed)
        mapping(bytes32 => int256) vpt;
        /// @dev poolId → smoothed force index EMA
        mapping(bytes32 => int256) forceIndexEma;
        /// @dev poolId → negative volume index
        mapping(bytes32 => uint256) nvi;
        /// @dev poolId → positive volume index
        mapping(bytes32 => uint256) pvi;
        /// @dev poolId → CUSUM statistic
        mapping(bytes32 => uint256) cusum;
        /// @dev poolId → CUSUM reference level
        mapping(bytes32 => uint256) cusumReference;
        /// @dev poolId → cumulative LVR (loss-versus-rebalancing)
        mapping(bytes32 => uint256) cumulativeLvr;
        /// @dev poolId → previous period close price (for OBV/VPT/Force)
        mapping(bytes32 => uint256) lastClosePrice;
        /// @dev poolId → previous period volume (for NVI/PVI)
        mapping(bytes32 => uint256) lastPeriodVolume;
    }

    // keccak256("volumeOracle.analytics")
    bytes32 internal constant STORAGE_SLOT = 0x3d6f4b2a8e1c5d7f9b0a2c4e6d8f0a1b3c5d7e9f0a2b4c6d8e0f1a3b5c7d9e;

    function layout() internal pure returns (VolumeAnalyticsStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
