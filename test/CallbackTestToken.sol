pragma solidity ^0.8.17;

interface IVestingWallet {
    function release(address) external;
}

contract CallbackTestToken {
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowances;
    address callback;
    uint state = 0;

    constructor(address wallet) {
        balances[msg.sender] = 1e24;
        callback = wallet;
    }

    function approve(address spender, uint amount) external {
        allowances[msg.sender][spender] = amount;
    }

    function transferFrom(address from, address to, uint amount) external {
        allowances[from][msg.sender] -= amount;
        _transfer(from, to, amount);
    }

    function transfer(address to, uint amount) external {
        _transfer(msg.sender, to, amount);
    }

    function _transfer(address from, address to, uint amount) internal {
        if (state == 0) {
            state++;
            IVestingWallet(callback).release(address(this));
        }
        balances[from] -= amount;
        balances[to] += amount;
    }

    function balanceOf(address addr) public view returns (uint) {
        return balances[addr];
    }

    function setState(uint _state) public {
        state = _state;
    }
}
