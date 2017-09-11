pragma solidity ^0.4.11;

import './main.sol';
import './dao.sol';

contract TasksHandler is Module {

    struct TaskListing {
        string metadata;
        address poster;
        uint rewardInWeis;
        uint[] rewardTokenIndexList;
        uint[] rewardTokenAmountList;
        uint rewardGoodRep;
        uint penaltyBadRep;
        bool isInvalid;
        mapping(address => bool) hasSubmitted; //Records whether a user has already submitted a solution.
        mapping(address => bool) hasBeenPenalized;
    }

    struct TaskSolution {
        string metadata;
        address submitter;
        bytes patchData;
        uint upvotes;
        uint downvotes;
        mapping(address => bool) hasVoted;
    }

    modifier needsRight(string right) {
        Dao dao = Dao(moduleAddress('DAO'));
        require(dao.memberHasRight(msg.sender, right));
        require(!dao.isBanned(msg.sender));
        _;
    }

    TaskListing[] public tasks;
    TaskSolution[][] public taskSolutions;

    uint public rewardRepCap;
    uint public penaltyRepCap;
    uint public rewardWeiCap;
    mapping(address => uint) public rewardTokenCap; //From token's address to cap

    event TaskSolutionAccepted(uint taskId, uint solutionId);

    function TasksHandler(address mainAddr) Module(mainAddr) {
        //Initialize reward caps
        rewardRepCap = 3;
        penaltyRepCap = 6;
        rewardWeiCap = 1 ether;
    }

    function publishTaskListing(
        string metadata,
        address poster,
        uint rewardInWeis,
        uint[] rewardTokenIndexList,
        uint[] rewardTokenAmountList,
        uint rewardGoodRep,
        uint penaltyBadRep
    )
        needsRight('submit_task')
    {
        require(rewardTokenAmountList.length == rewardTokenIndexList.length);

        require(rewardInWeis <= rewardWeiCap);
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);
        checkTokenCap(rewardTokenIndexList, rewardTokenAmountList);

        tasks.push(TaskListing({
            metadata: metadata,
            poster: poster,
            rewardInWeis: rewardInWeis,
            rewardTokenIndexList: rewardTokenIndexList,
            rewardTokenAmountList: rewardTokenAmountList,
            rewardGoodRep: rewardGoodRep,
            penaltyBadRep: penaltyBadRep,
            isInvalid: false
        }));
        taskSolutions.length += 1;
    }

    function invalidateTaskListingAtIndex(uint index) onlyMod('DAO') {
        require(index < tasks.length);
        tasks[index].isInvalid = true;
    }

    function submitSolution(address sender, string metadata, uint taskId, bytes patchData)
        needsRight('submit_solution')
    {
        require(taskId < tasks.length);

        TaskListing storage task = tasks[taskId];

        require(!task.isInvalid);
        require(sender != task.poster); //Prevent self-serving tasks

        require(!task.hasSubmitted[sender]);
        task.hasSubmitted[sender] = true;

        taskSolutions[taskId].push(TaskSolution({
            metadata: metadata,
            submitter: sender,
            patchData: patchData,
            upvotes: 0,
            downvotes: 0
        }));
    }

    function voteOnSolution(address sender, uint taskId, uint solId, bool isUpvote)
        needsRight('vote_solution')
    {
        require(taskId < tasks.length);
        require(solId < taskSolutions[taskId].length);

        TaskSolution storage sol = taskSolutions[taskId][solId];

        require(!sol.hasVoted[sender]);
        sol.hasVoted[sender] = true;

        if (isUpvote) {
            sol.upvotes += 1;
        } else {
            sol.downvotes += 1;
        }
    }

    function acceptSolution(address sender, uint taskId, uint solId) {
        require(taskId < tasks.length);
        TaskListing storage task = tasks[taskId];

        require(solId < taskSolutions[taskId].length);

        require(task.poster == sender);

        require(!task.hasBeenPenalized[taskSolutions[taskId][solId].submitter]);

        task.isInvalid = true;

        //Broadcast acceptance

        TaskSolutionAccepted(taskId, solId);

        //Pay submitter of solution
        Dao dao = Dao(moduleAddress('DAO'));
        dao.paySolutionReward(taskId, solId);
    }

    function setCap(string capType, uint newCap, address tokenAddress)
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

    function deleteRewardTokenCap(address tokenAddress)
        onlyMod('DAO')
    {
        delete rewardTokenCap[tokenAddress];
    }

    //Helpers

    function rewardTokenIndex(uint taskId, uint tokenId) returns(uint) {
        return tasks[taskId].rewardTokenIndexList[tokenId];
    }

    function rewardTokenAmount(uint taskId, uint tokenId) returns(uint) {
        return tasks[taskId].rewardTokenAmountList[tokenId];
    }

    function rewardTokenCount(uint taskId) returns(uint) {
        return tasks[taskId].rewardTokenAmountList.length;
    }

    function hasBeenPenalizedForTask(uint taskId, address memberAddr) returns(bool) {
        return tasks[taskId].hasBeenPenalized[memberAddr];
    }

    function setPenalizedStatus(uint taskId, address memberAddr, bool status) onlyMod('DAO') {
        tasks[taskId].hasBeenPenalized[memberAddr] = status;
    }

    function checkTokenCap(uint[] rewardTokenIndexList, uint[] rewardTokenAmountList) constant internal {
        Dao dao = Dao(moduleAddress('DAO'));
        for (uint i = 0; i < rewardTokenIndexList.length; i++) {
            uint id = rewardTokenIndexList[i];
            uint reward = rewardTokenAmountList[i];
            var (,tokenAddress) = dao.acceptedTokens(id);
            require(reward <= rewardTokenCap[tokenAddress]);
        }
    }

    function() {
        revert();
    }
}
