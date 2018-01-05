pragma solidity ^0.4.0;

import './main.sol';
import 'zeppelin-solidity/contracts/token/MintableToken.sol';

contract Token is MintableToken, Module {
    string public name;
    string public symbol;
    //Decimals given in Module's definition

    function Token(
        address _mainAddr,
        string _name,
        string _symbol
    )
        public
        Module(_mainAddr)
    {
        name = _name;
        symbol = _symbol;
    }
}
