// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Verifier interface
interface IProofVerifier {
    function verifyProof(bytes calldata publicValues_, bytes calldata proofBytes_) external view;
}