/*
    git_handler.sol
    Created by Zefram Lou (Zebang Liu) as a part of the WikiGit project.

    Barebone version of a contract that communicates with the Git implementation
    in the user interface component (e.g. a Javascript UI).
*/

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
