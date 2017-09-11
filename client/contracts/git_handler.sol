pragma solidity ^0.4.11;

import './main.sol';

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
