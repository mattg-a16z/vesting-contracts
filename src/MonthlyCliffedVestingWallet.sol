// TODO: license
pragma solidity ^0.8.0;

import "./DiscreteCliffedVestingWallet.sol";
import "./utils/UnixDaysToDate.sol";

contract MonthlyCliffedVestingWallet is DiscreteCliffedVestingWallet, UnixDaysToDate {

    uint64 constant SECONDS_IN_DAY = 86400;

    constructor(
        address beneficiary, 
        uint64 startTimestamp, 
        uint64 durationMonths, 
        uint64 cliffMonths
    ) DiscreteCliffedVestingWallet(
        beneficiary, 
        startTimestamp, 
        durationMonths, 
        cliffMonths
    ) {}
    
    function _timeUnitsElapsed(uint64 timestamp) public view override returns (uint256) {
        unchecked {
            if (timestamp < start()) {
                return 0;
            } else {
                (uint256 startY, uint256 startM, uint256 startD) = _daysToDate(uint64(start() / SECONDS_IN_DAY));
                (uint256 timestampY, uint256 timestampM, uint256 timestampD) = _daysToDate(timestamp / SECONDS_IN_DAY);
                
                uint256 startS = start() % SECONDS_IN_DAY;
                uint256 timestampS = timestamp % SECONDS_IN_DAY;
                if (timestampS < startS) timestampD--;
                if (timestampD < startD) timestampM--;

                return (timestampY - startY) * 12 + timestampM - startM;
            }
        }
    }
}