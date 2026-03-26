// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IVolumeOracle
/// @notice Public read interface for Tier 1 + Tier 2 volume metrics
interface IVolumeOracle {
    // ── Tier 1: Accumulators ────────────────────────────────────────

    function getCumulativeVolume(bytes32 poolId) external view returns (uint256 volumeA, uint256 volumeB);
    function getBuySellVolume(bytes32 poolId) external view returns (uint256 buyVolume, uint256 sellVolume);
    function getVolumeDelta(bytes32 poolId) external view returns (int256 delta);
    function getCumulativeVolumeDelta(bytes32 poolId) external view returns (int256 cvd);
    function getVolumeToTVLRatio(bytes32 poolId) external view returns (uint256 ratio);
    function getFeeVolume(bytes32 poolId) external view returns (uint256 feeVolumeA, uint256 feeVolumeB);
    function getNetVolumeFlow(bytes32 poolId) external view returns (int256 netFlow);

    // ── Tier 2: Analytics ───────────────────────────────────────────

    function getVWAP(bytes32 poolId) external view returns (uint256 vwap);
    function getVolumeEMA(bytes32 poolId) external view returns (uint256 emaShort, uint256 emaLong);
    function getVolumeOscillator(bytes32 poolId) external view returns (int256 oscillator);
    function getForceIndex(bytes32 poolId) external view returns (int256 forceIndex);
    function getOBV(bytes32 poolId) external view returns (int256 obv);
    function getVPT(bytes32 poolId) external view returns (int256 vpt);
    function getVolumeZScore(bytes32 poolId) external view returns (int256 zScore);
    function getNVIPVI(bytes32 poolId) external view returns (uint256 nvi, uint256 pvi);
    function getCUSUM(bytes32 poolId) external view returns (uint256 cusum, uint256 reference);
    function getBreakoutSignal(bytes32 poolId) external view returns (bool isBreakout, int256 zScore);
    function getLVR(bytes32 poolId) external view returns (uint256 cumulativeLvr);
}
