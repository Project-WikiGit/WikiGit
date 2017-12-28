/*
    tasks_handler.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the mechanisms for posting task listings, submitting
    task solutions, and accepting task solutions as the final answers. It should
    be possible to modify this file to allow compatability with third-party freelancing
    platforms.
*/

pragma solidity ^0.4.18;

import './main.sol';
import './dao.sol';
import './member_handler.sol';

contract TasksHandler is Module {
    struct TaskListing {
        string metadata; //Metadata of the task. Format dependent on the higher level UI.
        address poster;
        uint rewardInWeis;
        uint[] rewardTokenIdList; //IDs of the rewarded tokens in the recognizedTokenList of the DAO.
        uint[] rewardTokenAmountList; //Amount of rewarded tokens with respect to rewardTokenIdList.
        uint rewardGoodRep; //Reward in good reputation.
        uint penaltyBadRep; //Penalty in bad reputation if a solution is deemed malicious.
        bool isInvalid;
        uint acceptedSolutionID; //Index of the accepted solution.
        bool hasAcceptedSolution;
        mapping(address => bool) hasSubmitted; //Records whether a user has already submitted a solution.
        mapping(address => bool) hasBeenPenalized; //Recordes whether a user has been penalized for a malicious solution.
        mapping(address => uint) memberSolId; //From member address to index of member's solution submission.
    }

    /*
        Defines a task solution.
    */
    struct TaskSolution {
        string metadata; //Metadata of the task. Format dependent on the higher level UI.
        address submitter;
        bytes patchIPFSHash; //IPFS hash of the Git patch.
        /*
            Solution voting allow members to express their evaluations of a solution.
            Does not have any actual effect on the solution acceptance process.
        */
        uint upvotes;
        uint downvotes;
        mapping(address => bool) hasVoted;
    }

    modifier needsRight(string right) {
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(h.memberHasRight(msg.sender, right));
        require(! h.isBanned(msg.sender)); //Makes function declarations more concise.
        _;
    }

    TaskListing[] public taskList;
    TaskSolution[][] public taskSolutionList;

    /*
        Upper bounds for reward amounts.
    */
    uint public rewardRepCap;
    uint public penaltyRepCap;
    uint public rewardWeiCap;
    mapping(address => uint) public rewardTokenCap; //From token's address to cap

    event TaskSolutionAccepted(uint taskId, uint solutionId, bytes patchIPFSHash);

    function TasksHandler(address mainAddr) Module(mainAddr) public {
        //Initialize reward caps
        rewardRepCap = 3;
        penaltyRepCap = 6;
        rewardWeiCap = 1 ether;
    }

    function publishTaskListing(
        string metadata,
        address poster,
        uint rewardInWeis,
        uint[] rewardTokenIdList,
        uint[] rewardTokenAmountList,
        uint rewardGoodRep,
        uint penaltyBadRep
    )
        public
        needsRight('submit_task')
    {
        //Check format
        require(rewardTokenAmountList.length == rewardTokenIdList.length);

        //Check if reward exceeds cap
        require(rewardInWeis <= rewardWeiCap);
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);
        checkTokenCap(rewardTokenIdList, rewardTokenAmountList);

        taskList.push(TaskListing({
            metadata: metadata,
            poster: poster,
            rewardInWeis: rewardInWeis,
            rewardTokenIdList: rewardTokenIdList,
            rewardTokenAmountList: rewardTokenAmountList,
            rewardGoodRep: rewardGoodRep,
            penaltyBadRep: penaltyBadRep,
            isInvalid: false,
            acceptedSolutionID: 0,
            hasAcceptedSolution: false
        }));
        taskSolutionList.length += 1;
    }

    //Split out as an independent function to prevent StackTooDeep error
    function checkTokenCap(uint[] rewardTokenIndexList, uint[] rewardTokenAmountList) private view {
        Dao dao = Dao(moduleAddress('DAO'));
        for (uint i = 0; i < rewardTokenIndexList.length; i++) {
            uint id = rewardTokenIndexList[i];
            uint reward = rewardTokenAmountList[i];
            var (,tokenAddress) = dao.recognizedTokenList(id);
            require(reward <= rewardTokenCap[tokenAddress]);
        }
    }

    /*
        For part time contributors who don't have the right to post task listings with rewards.
    */
    function publishRewardlessTaskListing(
        string metadata,
        address poster,
        uint rewardGoodRep,
        uint penaltyBadRep
    )
        public
        needsRight('submit_task_rewardless')
    {
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);

        taskList.length += 1;

        TaskListing storage task = taskList[taskList.length - 1];
        task.metadata = metadata;
        task.poster = poster;
        task.rewardGoodRep = rewardGoodRep;
        task.penaltyBadRep = penaltyBadRep;

        taskSolutionList.length += 1;
    }

    function invalidateTaskListingAtIndex(uint index) public onlyMod('DAO') {
        require(index < taskList.length);
        taskList[index].isInvalid = true;
    }

    function submitSolution(
        uint taskId,
        string metadata,
        bytes patchIPFSHash
    )
        public
        needsRight('submit_solution')
    {
        require(taskId < taskList.length);

        TaskListing storage task = taskList[taskId];

        require(!task.isInvalid);
        require(msg.sender != task.poster); //Prevent self-serving tasks

        if (! task.hasSubmitted[msg.sender]) {
            task.hasSubmitted[msg.sender] = true;
            taskSolutionList[taskId].push(TaskSolution({
                metadata: metadata,
                submitter: msg.sender,
                patchIPFSHash: patchIPFSHash,
                upvotes: 0,
                downvotes: 0
            }));
            taskList[taskId].memberSolId[msg.sender] = taskSolutionList.length - 1;
        } else {
            uint solId = taskList[taskId].memberSolId[msg.sender];
            taskSolutionList[taskId][solId].metadata = metadata;
            taskSolutionList[taskId][solId].patchIPFSHash = patchIPFSHash;
        }
    }

    function voteOnSolution(
        address sender,
        uint taskId,
        uint solId,
        bool isUpvote
    )
        public
        needsRight('vote_solution')
    {
        require(taskId < taskList.length);
        require(solId < taskSolutionList[taskId].length);

        TaskSolution storage sol = taskSolutionList[taskId][solId];

        require(!sol.hasVoted[sender]);
        sol.hasVoted[sender] = true;

        if (isUpvote) {
            sol.upvotes += 1;
        } else {
            sol.downvotes += 1;
        }
    }

    /*
        Accepts a solution and pays the rewards to the solution submitter.
        Can only be called by the poster of the task listing.
    */
    function acceptSolution(uint taskId, uint solId) public {
        require(taskId < taskList.length); //Ensure that taskId is valid.
        TaskListing storage task = taskList[taskId];

        require(solId < taskSolutionList[taskId].length); //Ensure that solId is valid.

        TaskSolution storage sol = taskSolutionList[taskId][solId];

        require(task.poster == msg.sender); //Ensure that the caller is the poster of the task listing.

        require(!task.hasBeenPenalized[taskSolutionList[taskId][solId].submitter]);

        task.isInvalid = true;
        task.hasAcceptedSolution = true;
        task.acceptedSolutionID = solId;

        //Broadcast acceptance
        TaskSolutionAccepted(taskId, solId, sol.patchIPFSHash);

        //Pay submitter of solution
        Dao dao = Dao(moduleAddress('DAO'));
        dao.paySolutionReward(taskId, solId);
    }

    function setCap(
        string capType,
        uint newCap,
        address tokenAddress
    )
        public
        onlyMod('DAO')
    {
        if (keccak256(capType) == keccak256('wei')) {
            rewardWeiCap = newCap;
        } else if (keccak256(capType) == keccak256('good_rep')) {
            rewardRepCap = newCap;
        } else if (keccak256(capType) == keccak256('bad_rep')) {
            penaltyRepCap = newCap;
        } else if (keccak256(capType) == keccak256('token')) {
            rewardTokenCap[tokenAddress] = newCap;
        }
    }

    function deleteRewardTokenCap(address tokenAddress) public onlyMod('DAO')
    {
        delete rewardTokenCap[tokenAddress];
    }

    function setPenalizedStatus(uint taskId, address memberAddr, bool status) public onlyMod('DAO') {
        taskList[taskId].hasBeenPenalized[memberAddr] = status;
    }

    //Getters

    function tHasSubmitted(uint taskId, address addr) public view returns(bool) {
        return taskList[taskId].hasSubmitted[addr];
    }

    function tHasBeenPenalized(uint taskId, address addr) public view returns(bool) {
        return taskList[taskId].hasBeenPenalized[addr];
    }

    function tMemberSolId(uint taskId, address addr) public view returns(uint) {
        return taskList[taskId].memberSolId[addr];
    }

    function sHasVoted(uint taskId, uint solId, address addr) public view returns(bool) {
        return taskSolutionList[taskId][solId].hasVoted[addr];
    }

    function getTRewardTokenIndex(uint taskId, uint tokenId) public view returns(uint) {
        return taskList[taskId].rewardTokenIdList[tokenId];
    }

    function getTRewardTokenAmount(uint taskId, uint tokenId) public view returns(uint) {
        return taskList[taskId].rewardTokenAmountList[tokenId];
    }

    function getTRewardTokenListCount(uint taskId) public view returns(uint) {
        return taskList[taskId].rewardTokenAmountList.length;
    }

    //Fallback
    function() public {
        revert();
    }
}
