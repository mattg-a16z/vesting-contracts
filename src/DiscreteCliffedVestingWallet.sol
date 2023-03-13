// TODO: license
pragma solidity ^0.8.0;

import "openzeppelin-contracts/finance/VestingWallet.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

abstract contract DiscreteCliffedVestingWallet is VestingWallet, ReentrancyGuard {

    uint64 private immutable _cliff;

    constructor(
        address beneficiary, 
        uint64 startTimestamp, 
        uint64 durationInTimeUnits, 
        uint64 cliffInTimeUnits
    ) VestingWallet(
        beneficiary, 
        startTimestamp, 
        durationInTimeUnits
    ) {
        require(cliffInTimeUnits < durationInTimeUnits);
        _cliff = cliffInTimeUnits;
    }

    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }

    function release() public override virtual nonReentrant {
        super.release();
    }

    function release(address token) public override virtual nonReentrant {
        super.release(token);
    }

    /**
    * Vests at the end of the of the period, to make it vest at the beginning, adjust the start 1 time unit backward
    */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view override returns (uint256) {
        uint256 elapsed = _timeUnitsElapsed(timestamp);
        if (elapsed < cliff()) {
            return 0;
        } else if (elapsed > duration()) {
            return totalAllocation;
        } else {
            return totalAllocation * elapsed / duration();
        }
    }

    function _timeUnitsElapsed(uint64 timestamp) internal virtual view returns (uint256);
}
