// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VolumeOracleV2} from "../volume-oracle-v2/VolumeOracleV2.sol";

/// @title VolumeOracleHook
/// @notice Uniswap V4 hook that inherits from VolumeOracleV2 orchestrator.
///         Translates V4 hook callbacks into orchestrator accumulation calls.
///         No cross-contract calls on the hot path — inherits storage directly.
/// @dev Implements IHooks (afterSwap, afterAddLiquidity, afterRemoveLiquidity, beforeSwap)
contract VolumeOracleHook is VolumeOracleV2 {
    // TODO: Implement V4 hook interface
    //  - beforeSwap → tstorePreSwapState via delegatecall to protocol facet
    //  - afterSwap → _recordSwap(V4_FLAGS, poolId, hookData)
    //  - afterAddLiquidity → (future: position tracking)
    //  - afterRemoveLiquidity → (future: position tracking)
    //  - getHookPermissions() → return flags
}
