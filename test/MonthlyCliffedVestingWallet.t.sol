pragma solidity ^0.8.0;

import "../src/MonthlyCliffedVestingWallet.sol";
import "./tokens/TestToken.sol";
import "./tokens/CallbackTestToken.sol";
import "forge-std/Test.sol";

contract MonthlyCliffedVestingWalletTest is Test {

    uint256 constant UNIX_BASE_TO_BASE_DAY = 135080;
    uint256 constant DAYS_IN_400_YEARS =146097;
    uint256 constant DAYS_IN_100_YEARS = 36524;
    uint256 constant DAYS_IN_4_YEARS = 1461;
    uint256 constant DAYS_IN_MONTH_PACKED = 0x1d1f1f1e1f1e1f1f1e1f1e1f;

    // Storage to free stack
    uint256 startY;
    uint256 startM;
    uint256 startD;
    uint256 startS;
    uint256 iY;
    uint256 iM;
    uint256 iD;
    uint256 iS;

    /**
     * A simple (non-efficient) implementation of unix timestamp days to y, m, d
     */
    function daysToDateExpected(uint64 _days) internal view returns (uint256 _year, uint256 _month, uint256 _day) {
        uint256 daysSinceBase = (_days + UNIX_BASE_TO_BASE_DAY);

        uint256 qcCycles = daysSinceBase / DAYS_IN_400_YEARS;
        uint256 remainingDays = daysSinceBase % DAYS_IN_400_YEARS;
        uint256 cCycles = remainingDays / DAYS_IN_100_YEARS;
        if (cCycles == 4) cCycles--;
        remainingDays -= cCycles * DAYS_IN_100_YEARS;
        uint256 qCycles = remainingDays / DAYS_IN_4_YEARS;
        if (qCycles==25) qCycles--;
        remainingDays -= qCycles * DAYS_IN_4_YEARS;
        uint256 remainingYears = remainingDays / 365;
        if (remainingYears==4) remainingYears--;
        remainingDays -= remainingYears*365;
        uint256 yearsSinceBase = remainingYears + 4*qCycles + 100*cCycles + 400*qcCycles;
        uint256 m;
        for (m=0; m<96; m+=8) {
            uint256 daysInM = (DAYS_IN_MONTH_PACKED >> m) & 0xff;
            if (remainingDays<daysInM) break;
            remainingDays -= daysInM;
        }
        _year = 1600 + yearsSinceBase;
        _month = (m/8)+3;
        if (_month>12) {
            _year++;
            _month -= 12;
        } 
        _day = remainingDays + 1;
    }

    function monthsElapsed() internal returns (uint256) {
        if (iS < startS) iD--;
        if (iD < startD) iM--;
        return (iY-startY)*12 + iM - startM;
    }

    function subOrZero(uint a, uint b) internal pure returns (uint256) {
        if (b > a) {
            return 0;
        } else {
            return a-b;
        }
    }
    function createWallet(address beneficiary, uint64 start, uint64 cliff, uint64 duration) internal returns (DiscreteCliffedVestingWallet) {
        return DiscreteCliffedVestingWallet(payable(new MonthlyCliffedVestingWallet(beneficiary, start, duration, cliff)));
    }

    function expectedVestAmount(uint amount, uint64 start, uint64 duration, uint64 time) internal pure returns (uint) {
        if (time > start + duration) return amount;
        else if (start > time) return 0;
        else return amount * (time - start) / duration;
    }

    function testExecuteVestingSchedule(address beneficiary, uint64 start, uint64 cliff, uint64 duration, uint256 amount) public {

        // Assumptions - mostly bounding because forge assumes will eventually cause the test to fail
        vm.assume(beneficiary != address(0));
        // Feb 27 2003 to Feb 27 2403
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 400)));
        // Between 6 months and 100 years
        duration = uint64(bound(duration, 6, 1200));
        cliff = uint64(bound(cliff, 0, duration - 1));
        amount = uint256(bound(amount, 1, 2^196));

        TestToken token = new TestToken(amount);
        DiscreteCliffedVestingWallet wallet = createWallet(beneficiary, start, cliff, duration);
        token.transfer(address(wallet), amount);
        
        (startY, startM, startD) = daysToDateExpected(start/86400);
        startS = start % 86400;
        uint256 durationSeconds = duration * 2447 * 86400 / 80; // approximation using 2447/80 as days in month
        for (uint256 i=subOrZero(start, durationSeconds); i<start+2*durationSeconds; i+=durationSeconds/30+1) {
            vm.warp(i);
            (iY, iM, iD) = daysToDateExpected(uint64(i/86400));
            iS = i % 86400;
            uint256 expectedElapsed = 0;
            if (i >= start) {
                expectedElapsed = monthsElapsed(); 
            } 
            wallet.release(address(token));
            if (expectedElapsed < cliff) {
                assertEq(token.balanceOf(beneficiary), 0);
                assertEq(wallet.released(address(token)), 0);
            } else if (expectedElapsed < duration) {
                uint256 expected = amount * expectedElapsed / duration;
                assertEq(token.balanceOf(beneficiary), expected);
                assertEq(wallet.released(address(token)), expected);
            } else {
                assertEq(token.balanceOf(beneficiary), amount);
                assertEq(wallet.released(address(token)), amount);
            }
        }
    }

    function testTokenReentrancy() public {
        uint amount = 1e20;
        DiscreteCliffedVestingWallet wallet = createWallet(address(this), 1677517796, 1677517796 + (86400*20), 1677517796 + (86400*100));
        
        // pre-transfer callback
        PreTransferCallbackTestToken token = new PreTransferCallbackTestToken(address(wallet));
        token.balanceOf(address(this));
        token.setState(1); // disable the callback
        token.transfer(address(wallet), amount);
        token.transfer(address(1), token.balanceOf(address(this))); //remove any extra
        token.setState(0);
        uint time = 1677517796 + (86400*25); // after the cliff, within the vesting schedule
        vm.warp(time);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        wallet.release(address(token)); // This will trigger release twice
        
        // post-transfer callback
        PostTransferCallbackTestToken token2 = new PostTransferCallbackTestToken(address(wallet));
        token2.balanceOf(address(this));
        token2.setState(1); // disable the callback
        token2.transfer(address(wallet), amount);
        token2.transfer(address(1), token.balanceOf(address(this))); //remove any extra
        token2.setState(0);
        time = 1677517796 + (86400*25); // after the cliff, within the vesting schedule
        vm.warp(time);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        wallet.release(address(token2)); // This will trigger release twice
    }
}
