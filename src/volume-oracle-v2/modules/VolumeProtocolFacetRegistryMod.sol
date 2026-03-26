// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVolumeProtocolFacet} from "../interfaces/IVolumeProtocolFacet.sol";

/// @title VolumeProtocolFacetRegistryMod
/// @notice Diamond-style namespaced storage for the protocol facet registry.
///         Maps bytes2 protocol flags → IVolumeProtocolFacet address.
///         Slot: keccak256("volumeOracle.protocolRegistry")
library VolumeProtocolFacetRegistryMod {
    struct ProtocolRegistryStorage {
        /// @dev protocolFlags → facet implementation address
        mapping(bytes2 => IVolumeProtocolFacet) facets;
    }

    // keccak256("volumeOracle.protocolRegistry")
    bytes32 internal constant STORAGE_SLOT = 0x5f8b6d4c0a3e7f9b1d2c4e6a8f0b1c3d5e7f9a0b2c4d6e8f0a1b3c5d7e9f0a;

    function layout() internal pure returns (ProtocolRegistryStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
