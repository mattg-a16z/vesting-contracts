pragma solidity ^0.8.0;

import "../src/ContinuousCliffedVestingWallet.sol";
import "./tokens/TestToken.sol";
import "./tokens/CallbackTestToken.sol";
import "forge-std/Test.sol";

contract ContinuousCliffedVestingWalletTest is Test {

    function createWallet(address beneficiary, uint64 start, uint64 cliff, uint64 duration) internal returns (DiscreteCliffedVestingWallet) {
        return DiscreteCliffedVestingWallet(payable(new ContinuousCliffedVestingWallet(beneficiary, start, duration, cliff)));
    }

    function expectedVestAmount(uint amount, uint64 start, uint64 duration, uint64 time) internal pure returns (uint) {
        if (time > start + duration) return amount;
        else if (start > time) return 0;
        else return amount * (time - start) / duration;
    }

    function subOrZero(uint a, uint b) internal pure returns (uint256) {
        if (b > a) {
            return 0;
        } else {
            return a-b;
        }
    }

    function testExecuteVestingSchedule(address beneficiary, uint64 start, uint64 duration, uint64 cliff, uint256 amount) public {

        // Assumptions - mostly bounding because forge assumes will eventually cause the test to fail
        vm.assume(beneficiary != address(0));
        // Feb 27 2003 to Feb 27 2403
        start = uint64(bound(start, 1677517796 - (86400 * 365 * 20), 1677517796 + (86400 * 365 * 400)));
        // Between one day and about 20 years
        duration = uint64(bound(duration, 86400, 86400*365*100));
        cliff = uint64(bound(cliff, 0, duration - 1));
        amount = uint256(bound(amount, 1, 2^196));

        TestToken token = new TestToken(amount);
        address addressToken = address(token);
        DiscreteCliffedVestingWallet wallet = createWallet(beneficiary, start, cliff, duration);
        token.transfer(address(wallet), amount);

        uint256 durationSeconds = duration;
        for (uint i=subOrZero(start, durationSeconds); i<start+2*durationSeconds; i+=durationSeconds/30+1) {
            vm.warp(i);
            wallet.release(addressToken);
            if (i < start+cliff) {
                assertEq(token.balanceOf(beneficiary), 0);
                assertEq(wallet.released(addressToken), 0);
            } else if (i < start+duration) {
                uint256 expected = (i - start) * amount / duration;
                console.log(i);
                assertEq(token.balanceOf(beneficiary), expected);
                assertEq(wallet.released(addressToken), expected);
            } else {
                assertEq(token.balanceOf(beneficiary), amount);
                assertEq(wallet.released(addressToken), amount);
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
