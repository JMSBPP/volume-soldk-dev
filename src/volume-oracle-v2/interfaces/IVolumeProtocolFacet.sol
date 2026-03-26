// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IVolumeProtocolFacet
/// @notice Behavioral interface for protocol-specific volume data abstraction.
///         Called via delegatecall from VolumeOracleV2 orchestrator.
///         Each protocol (V4, V3, custom AMM) implements this interface.
interface IVolumeProtocolFacet {
    // ── Swap data extraction ────────────────────────────────────────

    /// @notice Derive swap direction from protocol-specific hook/callback data
    function swapDirection(bytes calldata hookData) external view returns (bool isBuy);

    /// @notice Extract swap amount (absolute) from protocol-specific data
    function swapAmount(bytes calldata hookData) external view returns (uint256 amountA, uint256 amountB);

    /// @notice Extract fee amount from the swap
    function swapFee(bytes calldata hookData) external view returns (uint256 feeA, uint256 feeB);

    /// @notice Get current price from the protocol's pool state
    function currentPrice(bytes calldata hookData, bytes32 poolId) external view returns (uint256 price);

    /// @notice Get current tick (for concentrated liquidity protocols)
    function currentTick(bytes calldata hookData, bytes32 poolId) external view returns (int24 tick);

    // ── Transient storage (per-transaction caching) ─────────────────

    /// @notice Cache pre-swap state for delta computation
    function tstorePreSwapState(bytes32 poolId, uint256 price, int24 tick) external;

    /// @notice Load cached pre-swap state
    function tloadPreSwapState(bytes32 poolId) external view returns (uint256 price, int24 tick);

    // ── State writes (delegatecall context) ─────────────────────────

    /// @notice Accumulate volume terms into orchestrator storage
    function addVolumeTerm(
        bytes32 poolId,
        uint256 amountA,
        uint256 amountB,
        bool isBuy,
        uint256 price
    ) external;
}
