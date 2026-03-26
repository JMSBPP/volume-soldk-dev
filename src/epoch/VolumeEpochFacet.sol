// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVolumeEpoch} from "./interfaces/IVolumeEpoch.sol";
import {VolumeEpochStorageMod} from "./modules/VolumeEpochStorageMod.sol";

/// @title VolumeEpochFacet
/// @notice Optional facet for time-windowed volume metric accumulation.
///         Manages epoch boundaries, resets, and per-epoch state snapshots.
///         Deployed independently — pools opt in via initializeEpochPool().
contract VolumeEpochFacet is IVolumeEpoch {
    // TODO: Implement epoch lifecycle
    //  - initializeEpochPool → set epochLength, currentEpochId, startTimestamp
    //  - checkEpochBoundary → compare block.timestamp against start + length
    //  - addEpochTerm → accumulate into current epoch's EpochState
    //  - getEpochVolume / getEpochAnalytics → read from epochStates mapping
}
