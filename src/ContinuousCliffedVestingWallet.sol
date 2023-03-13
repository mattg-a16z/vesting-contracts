// TODO: license
pragma solidity ^0.8.0;

import "./DiscreteCliffedVestingWallet.sol";

contract ContinuousCliffedVestingWallet is DiscreteCliffedVestingWallet {

    constructor(
        address beneficiary, 
        uint64 startTimestamp, 
        uint64 durationSeconds, 
        uint64 cliffSeconds
    ) DiscreteCliffedVestingWallet(
        beneficiary, 
        startTimestamp, 
        durationSeconds, 
        cliffSeconds
    ) {}

    function _timeUnitsElapsed(uint64 timestamp) internal view override returns (uint256) {
        unchecked {
            if (timestamp < start()) {
                return 0;
            } else {
                return timestamp - start();
            }
        }
    }
}