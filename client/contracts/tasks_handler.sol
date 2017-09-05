pragma solidity ^0.4.11;

import './main.sol';
//import './dao.sol';

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
        uint taskId;
        bytes patchData;
        uint upvotes;
        uint downvotes;
        mapping(address => bool) hasVoted;
    }

    TaskListing[] public tasks;
    TaskSolution[][] public taskSolutions;

    event TaskSolutionAccepted(uint taskId, uint solutionId);

    function TasksHandler(address mainAddr) Module(mainAddr) {

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
        onlyMod('DAO')
    {
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

    function submitSolution(address sender, string metadata, uint taskId, bytes patchData) onlyMod('DAO') {
        require(taskId < tasks.length);

        TaskListing storage task = tasks[taskId];

        require(!task.isInvalid);
        require(sender != task.poster); //Prevent self-serving tasks

        require(!task.hasSubmitted[sender]);
        task.hasSubmitted[sender] = true;

        taskSolutions[taskId].push(TaskSolution({
            metadata: metadata,
            submitter: sender,
            taskId: taskId,
            patchData: patchData,
            upvotes: 0,
            downvotes: 0
        }));
    }

    function voteOnSolution(address sender, uint taskId, uint solId, bool isUpvote) onlyMod('DAO') {
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

    function acceptSolution(address sender, uint taskId, uint solId) onlyMod('DAO') {
        require(taskId < tasks.length);
        TaskListing storage task = tasks[taskId];

        require(solId < taskSolutions[taskId].length);

        require(task.poster == sender);

        task.isInvalid = true;

        //Broadcast acceptance

        TaskSolutionAccepted(taskId, solId);

        //Pay submitter of solution
        //Dao dao = Dao(moduleAddress('DAO'));
        //dao.paySolutionReward(taskId, solId);
    }

    function() {
        revert();
    }
}
