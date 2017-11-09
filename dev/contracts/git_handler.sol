/*
    git_handler.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    Barebone version of a contract that communicates with the Git implementation
    in the user interface component (e.g. a Javascript UI).
*/

pragma solidity ^0.4.18;

import './main.sol';
import './tasks_handler.sol';

contract GitHandler is Module {
    /*
        The Git handler stores the entire history of the Git repository's IPFS hash as a tree
        identical to the type of tree structure used in Git itself.

        A new IPFS hash that incorporates the most recent commit would point to
        the current hash, pushed to ipfsHashes by the original poster of the task.
        If currentHashID had been changed to the ID of a hash that's lower in the tree,
        a new branch would automatically be formed upon pushing a new hash.

        This design ensures that any attack on the Git repo (e.g. setting a new
        IPFS hash that points to a malicious repo) can be easily reverted by
        changing currentHashID to the index of the IPFS hash of the last working repo,
        since no info is ever deleted.
    */
    bytes[] public ipfsHashTree; //Stores the tree of the IPFS hashes of the different states of the Git repository.
    mapping(uint => uint) public prevHashIDPointer; //Stores the pointers pointing from an IPFS hash's index to the index of the previous hash with respect to the tree structure.
    uint public currentHashID; //Stores the index of the IPFS hash of the Git repository at the current state.

    function GitHandler(bytes repoHash, address mainAddr) Module(mainAddr) public {
        ipfsHashTree.push(repoHash);
        prevHashIDPointer[0] = 0; //For clarity
        currentHashID = 0; //For clarity
    }

    function setCurrentIPFSHashID(uint id) public onlyMod('DAO') {
        currentHashID = id;
    }

    function commitTaskSolutionToRepo(
        uint taskId,
        uint solId,
        bytes newHash
    )
        public
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (,poster,,,,isInvalid, acceptedSolutionID, hasAcceptedSolution) = handler.taskList(taskId);
        var (_,submitter,) = handler.taskSolutionList(taskId, solId);

        require(poster == msg.sender); //Only the task's poster can commit.
        require(hasAcceptedSolution); //Can only commit after a solution has been accepted.
        require(isInvalid);
        require(acceptedSolutionID == solId); //Has to be the accepted solution.
        require(!handler.tHasBeenPenalized(taskId, submitter)); //Solution can't have been penalized.

        ipfsHashTree.push(newHash);
        prevHashIDPointer[ipfsHashTree.length - 1] = currentHashID;
        currentHashID = ipfsHashTree.length - 1;
    }

    //Getters

    function getCurrentIPFSHash() public view returns(bytes hash) {
        return ipfsHashTree[currentHashID];
    }

    function getIPFSHashTreeCount() public view returns(uint count) {
        return ipfsHashTree.length;
    }

    //Fallback
    function() public {
        revert();
    }
}
