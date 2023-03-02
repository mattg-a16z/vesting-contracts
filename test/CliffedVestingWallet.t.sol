pragma solidity ^0.8.0;

import "../src/CliffedVestingWallet.sol";
import "./TestToken.sol";
import "./CallbackTestToken.sol";
import "forge-std/Test.sol";

contract CliffedVestingWalletTest is Test {

    function createWallet(address beneficiary, uint64 start, uint64 cliff, uint64 duration) internal returns (CliffedVestingWallet) {
        return new CliffedVestingWallet(beneficiary, start, cliff, duration);
    }

    function expectedVestAmount(uint amount, uint64 start, uint64 duration, uint64 time) internal pure returns (uint) {
        if (time > start + duration) return amount;
        else if (start > time) return 0;
        else return amount * (time - start) / duration;
    }

    function testExecuteVestingSchedule(address beneficiary, uint64 start, uint64 cliff, uint64 duration) public {

        // Assumptions - mostly bounding because forge assumes will eventually cause the test to fail
        vm.assume(beneficiary != address(0));
        // Feb 27 2003 to Feb 27 2043
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 20)));
        // Between one day and about 20 years
        duration = uint64(bound(duration, 86400, 86400*365*20));
        // Cliff must be between unix start time (1970) and the end of the vesting period
        cliff = uint64(bound(cliff, 0, start + duration));

        // 100 1e18 tokens (effectively a percentage)
        uint amount = 1e20;

        TestToken token = new TestToken();
        address addressToken = address(token);
        CliffedVestingWallet wallet = CliffedVestingWallet(createWallet(beneficiary, start, cliff, duration));
        token.transfer(address(wallet), amount);
        
        // no time elapsed (need to consider where the cliff may be)
        vm.warp(start - 1000);
        if (start - 1000 < cliff) {
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
        }
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == 0); // in all cases, balance should be 0

        // Cliff boundary testing, if cliff is 0, we can't be "before the cliff"
        if (cliff > 0) {
            vm.warp(cliff - 1);
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
            wallet.release(addressToken);
        }

        // go to the cliff, make sure it doesn't revert
        // because of how the cliff works, when we go backwards to test vesting the amount will be fine
        vm.warp(cliff);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == expectedVestAmount(amount, start, duration, cliff));

        // do approximately 30 vests, making sure the amounts make sense
        for (uint64 i=0; i<duration; i+=(duration/30+1)) {
            uint64 time = start + i;
            vm.warp(time);
            if (time >= cliff) {
                wallet.release(addressToken);
                assertTrue(token.balanceOf(beneficiary) == expectedVestAmount(amount, start, duration, time));
            } else {
                vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
                wallet.release(addressToken);
            }
        }

        // duration elapsed
        vm.warp(start + duration);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == amount);

        vm.warp(start + duration + 1000);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == amount);
        assertTrue(token.balanceOf(address(wallet)) == 0);
    }

    function testReleasedTracking(address beneficiary, uint64 start, uint64 cliff, uint64 duration) public {

        // Assumptions - mostly bounding because forge assumes will eventually cause the test to fail
        vm.assume(beneficiary != address(0));
        // Feb 27 2003 to Feb 27 2043
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 20)));
        // Between one day and about 20 years
        duration = uint64(bound(duration, 86400, 86400*365*20));
        // Cliff must be between unix start time (1970) and the end of the vesting period
        cliff = uint64(bound(cliff, 0, start + duration));

        // 100 1e18 tokens (effectively a percentage)
        uint amount = 1e20;

        TestToken token = new TestToken();
        address addressToken = address(token);
        CliffedVestingWallet wallet = CliffedVestingWallet(createWallet(beneficiary, start, cliff, duration));
        token.transfer(address(wallet), amount);    

        // no time elapsed (need to consider where the cliff may be)
        vm.warp(start - 1000);
        if (start - 1000 < cliff) {
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
        }
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));

        // Cliff boundary testing
        if (cliff > 0) {
            vm.warp(cliff - 1);
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
            wallet.release(addressToken);
        }

        vm.warp(cliff);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));

        for (uint64 i=0; i<duration; i+=(duration/30+1)) {
            uint64 time = start + i;
            vm.warp(time);
            if (time >= cliff) {
                wallet.release(addressToken);
                assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));
            } else {
                vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
                wallet.release(addressToken);
                assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));
            }
        }

        // duration elapsed testing
        vm.warp(start + duration);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));

        vm.warp(start + duration + 1000);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == wallet.released(addressToken));
    }

    function testTokenReentrancy() public {
        uint amount = 1e20;
        CliffedVestingWallet wallet = CliffedVestingWallet(createWallet(address(this), 1677517796, 1677517796 + (86400*20), 1677517796 + (86400*100)));
        CallbackTestToken token = new CallbackTestToken(address(wallet));
        token.balanceOf(address(this));
        token.setState(1); // disable the callback
        token.transfer(address(wallet), amount);
        token.transfer(address(1), token.balanceOf(address(this))); //remove any extra
        token.setState(0);
        uint time = 1677517796 + (86400*25); // after the cliff, within the vesting schedule
        vm.warp(time);
        vm.expectRevert("ReentrancyGuard: reentrant call");
        wallet.release(address(token)); // This will trigger release twice
    }
}
