// TODO: license
pragma solidity ^0.8.0;

import "./DiscreteCliffedVestingWallet.sol";

contract WeeklyCliffedVestingWallet is DiscreteCliffedVestingWallet {

    uint constant SECONDS_IN_WEEK = 604800;

    constructor(
        address beneficiary, 
        uint64 startTimestamp, 
        uint64 durationWeeks, 
        uint64 cliffWeeks
    ) DiscreteCliffedVestingWallet(
        beneficiary, 
        startTimestamp, 
        durationWeeks, 
        cliffWeeks
    ) {}
    function _timeUnitsElapsed(uint64 timestamp) public view override returns (uint256) {
        unchecked {
            if (timestamp < start()) {
                return 0;
            } else {
                return (timestamp - start()) / SECONDS_IN_WEEK;
            }
        }
    }
}