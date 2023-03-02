// TODO: license
pragma solidity ^0.8.0;

import "openzeppelin-contracts/finance/VestingWallet.sol";
import "openzeppelin-contracts/security/ReentrancyGuard.sol";

contract CliffedVestingWallet is VestingWallet, ReentrancyGuard {

    uint64 private immutable _cliff;

    constructor(address beneficiary, uint64 startTimestamp, uint64 cliffTimestamp, uint64 durationSeconds) VestingWallet(beneficiary, startTimestamp, durationSeconds) {
        require(cliffTimestamp <= startTimestamp + durationSeconds, "CliffedVestingWallet: cliff must occur during vesting");
        _cliff = cliffTimestamp;
    }

    function cliff() public view virtual returns (uint256) {
        return _cliff;
    }

    function release() public override nonReentrant {
        require(cliff() <= block.timestamp, "CliffedVestingWallet: cannot release until the cliff");
        super.release();
    }

    function release(address token) public override nonReentrant {
        require(cliff() <= block.timestamp, "CliffedVestingWallet: cannot release until the cliff");
        super.release(token);
    }
}
