pragma solidity ^0.4.18;


contract ERC20 {

    function totalSupply() public view returns (uint totalSupply);

    function balanceOf(address _owner) public view returns (uint balance);

    function transfer(address _to, uint _value) public returns (bool success);

    function transferFrom(address _from, address _to, uint _value) public returns (bool success);

    function approve(address _spender, uint _value) public returns (bool success);

    function allowance(address _owner, address _spender) public view returns (uint remaining);

    event Transfer(address indexed _from, address indexed _to, uint _value);

    event Approval(address indexed _owner, address indexed _spender, uint _value);

}