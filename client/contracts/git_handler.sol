pragma solidity ^0.4.11;

import './main.sol';

/*
    Barebone version of a contract that communicates with the higher level interface (e.g. a Javascript UI).
*/
contract GitHandler is Module {
    event ExecuteConsoleCommand(string command);

    function GitHandler(address mainAddr) Module(mainAddr) {}

    function executeConsoleCommand(string command) onlyMod('DAO') {
        ExecuteConsoleCommand(command);
    }

    function() {
        revert();
    }
}
