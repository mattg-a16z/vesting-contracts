// TODO: license
pragma solidity ^0.8.0;

contract UnixDaysToDate {

    /**
     * Uses Fliegel and van Flandern algorithm for converting from timestamp to date
     */
    function _daysToDate(uint64 _days) internal pure returns(uint256 _year, uint256 _month, uint256 _day) {
        unchecked {
            uint256 L = _days + 68569 + 2440588; // Convert to march 1 4800 BCE
            uint256 N = (4 * L) / 146097; // 4 * number of 400 year cycles
            L = L - (146097 * N + 3) / 4; // subtract out the 400 year cycles (rounding up)
            _year = (4000 * (L+1)) / 1461001; // number of leap years (days / 1461.001)
            L = L - (1461 * _year) / 4 + 31; // subtract out the leap years
            _month = (80 * L) / 2447; // Get month by dividing by 30.5875
            _day = L - (2447 * _month) / 80; // Remove months to get remaining days
            L = _month / 11; // Check if the month wraps around (11 is Jan, 12 is Feb)
            _month = _month + 2 - 12 * L; // translate month into real month
            _year = 100 * (N - 49) + _year + L; // translate from 4800 BCE frame to CE frame
        }
    }
}