// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IProofVerifier} from "../interfaces/IVerifier.sol";

contract MockVerifier is IProofVerifier {
    error InvalidProof();

    uint256 public expectedProofLength = 0;

    constructor() {}

    function verifyProof(bytes calldata, /* publicValues */ bytes calldata proofBytes) external view {
        if (proofBytes.length != expectedProofLength) revert InvalidProof();
    }
}