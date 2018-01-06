/*
    repo_handler.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    Records the IPFS hash of the DASP's repo. Team members are responsible for incorporating the latest task solutions
    into the current repo and updating their personal IPFS hash. The UI would display the hash with majority support as
    the repo's hash.
*/

pragma solidity ^0.4.18;

import './main.sol';
import './member_handler.sol';

contract RepoHandler is Module {
    modifier needsRight(string right) {
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(h.memberHasRight(msg.sender, right));
        require(! h.isBanned(msg.sender)); //Makes function declarations more concise.
        _;
    }

    mapping(address => bytes) personalIPFSHashes;

    function RepoHandler(address _mainAddr) Module(_mainAddr) public {}

    function setPersonalHash(bytes _hash) public needsRight('accept_hash') {
        personalIPFSHashes[msg.sender] = _hash;
    }

    //Fallback
    function() public {
        revert();
    }
}
