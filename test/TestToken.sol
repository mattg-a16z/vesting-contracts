pragma solidity ^0.8.17;

contract TestToken {
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowances;

    constructor() {
        balances[msg.sender] = 1e24;
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
        balances[from] -= amount;
        balances[to] += amount;
    }

    function balanceOf(address addr) public view returns (uint) {
        return balances[addr];
    }

}
