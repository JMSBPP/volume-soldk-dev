// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {VolumeAccumulatorsStorageMod} from "../../volume-oracle/modules/VolumeAccumulatorsStorageMod.sol";

/// @title VolumeAccumulatorsReader
/// @notice Standalone stateless view contract for reading Tier 1 volume accumulators.
///         Reads directly from the orchestrator's namespaced storage slots.
///         Deploy once, point at any VolumeOracleV2 instance.
contract VolumeAccumulatorsReader {
    // TODO: Implement view functions that read orchestrator storage
    //  - Uses staticcall against orchestrator address
    //  - Or deployed as a library consumed by off-chain tooling
}
