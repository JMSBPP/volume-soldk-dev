// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title LibCall
/// @notice Delegatecall helper with revert propagation.
///         Used by VolumeOracleV2 to dispatch to protocol facets.
/// @dev Mirrors ThetaSwap's LibCall pattern.
library LibCall {
    // TODO: Implement delegateCallContract(address target, bytes memory data) → bytes memory
}
