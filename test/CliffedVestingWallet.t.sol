pragma solidity ^0.8.0;

import "../src/CliffedVestingWallet.sol";
import "./TestToken.sol";
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

        vm.assume(beneficiary != address(0));
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 20)));
        duration = uint64(bound(duration, 86400, 86400*365*20));
        cliff = uint64(bound(cliff, 0, start + duration));

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

        vm.warp(start);
        if (start < cliff) {
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
        }
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == 0); // in all cases, balance should be 0

        // Cliff boundary testing
        if (cliff > 0) {
            vm.warp(cliff - 1);
            vm.expectRevert("CliffedVestingWallet: cannot release until the cliff");
            wallet.release(addressToken);
        }

        vm.warp(cliff);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == expectedVestAmount(amount, start, duration, cliff));

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

        // duration elapsed testing
        vm.warp(start + duration);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == amount);

        vm.warp(start + duration + 1000);
        wallet.release(addressToken);
        assertTrue(token.balanceOf(beneficiary) == amount);
    }

    function testReleasedTracking(address beneficiary, uint64 start, uint64 cliff, uint64 duration) public {

        vm.assume(beneficiary != address(0));
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 20)));
        duration = uint64(bound(duration, 86400, 86400*365*20));
        cliff = uint64(bound(cliff, 0, start + duration));

        // Same exact test format for exercising the vesting schedule, 
        // but we want to know the amount released is always the actual amount transferred
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

        vm.warp(start);
        if (start < cliff) {
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
}
