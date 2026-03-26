// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVolumeOracle} from "../volume-oracle/interfaces/IVolumeOracle.sol";
import {IVolumeProtocolFacet} from "./interfaces/IVolumeProtocolFacet.sol";
import {VolumeAccumulatorsStorageMod} from "../volume-oracle/modules/VolumeAccumulatorsStorageMod.sol";
import {VolumeAnalyticsStorageMod} from "../volume-oracle/modules/VolumeAnalyticsStorageMod.sol";
import {VolumeProtocolFacetRegistryMod} from "./modules/VolumeProtocolFacetRegistryMod.sol";

/// @title VolumeOracleV2
/// @notice Protocol-agnostic orchestrator for modular volume metric accumulation.
///         Delegates protocol-specific data extraction to registered facets via delegatecall.
///         Owns all storage. Metric readers are separate view contracts.
/// @dev Follows ThetaSwap FCI V2 orchestrator pattern.
abstract contract VolumeOracleV2 is IVolumeOracle {
    // TODO: Implement orchestrator logic
    //  - registerProtocolFacet(bytes2 flags, IVolumeProtocolFacet facet)
    //  - _recordSwap(bytes2 protocolFlags, bytes32 poolId, bytes calldata hookData)
    //  - _accumulateTier1(...)
    //  - _accumulateTier2(...)
    //  - All IVolumeOracle view function implementations
}
