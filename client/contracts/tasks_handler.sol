pragma solidity ^0.4.0;

import './main.sol';
import './dao.sol';

contract TasksHandler is Module {

    struct TaskListing {
        string metadata;
        address poster;
        uint rewardInWeis;
        string[] rewardTokenSymbolList;
        uint[] rewardInTokensList;
        uint rewardGoodRep;
        uint penaltyBadRep;
        bool isInvalid;
        TaskSolution[] solutions;
        mapping(address => bool) hasSubmitted; //Records whether a user has already submitted a solution.
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

    event TaskSolutionAccepted(uint taskId, uint solutionId);

    function TasksHandler(address mainAddr) Module(mainAddr) {

    }

    function publishTaskListing(TaskListing task) onlyMod('DAO') {
        tasks.push(task);
    }

    function invalidateTaskListingAtIndex(uint index) onlyMod('DAO') {
        require(index < tasks.length);
        tasks[index].isInvalid = true;
    }

    function submitSolution(address sender, string metadata, uint taskId, bytes patchData) onlyMod('DAO') {
        require(taskId < tasks.length);
        TaskListing task = tasks[taskId];

        require(!task.isInvalid);

        require(!task.hasSubmitted[sender]);
        task.hasSubmitted[sender] = true;

        TaskSolution solution = TaskSolution({
            metadata: metadata,
            submitter: sender,
            taskId: taskId,
            patchData: patchData
        });

        task.solutions.push(solution);
    }

    function voteOnSolution(address sender, uint taskId, uint solId, bool isUpvote) onlyMod('DAO') {
        require(taskId < tasks.length);
        TaskListing task = tasks[taskId];

        require(solId < task.solutions.length);
        TaskSolution sol = task.solutions[solId];

        require(!sol.hasVoted[sender]);
        sol.hasVoted[sender] = true;

        if (isUpvote) {
            sol.upvotes += 1;
        } else {
            sol.downvotes += 1;
        }
    }

    //Todo: implement accepting task solutions
    function acceptSolution(address sender, uint taskId, uint solId) onlyMod('DAO') {
        require(taskId < tasks.length);
        TaskListing task = tasks[taskId];

        require(solId < task.solutions.length);
        TaskSolution sol = task.solutions[solId];

        require(task.poster == sender);
        require(sol.submitter != sender); //Prevent self-serving tasks

        task.isInvalid = true;

        //Broadcast acceptance

        TaskSolutionAccepted(taskId, solId);

        //Pay submitter of solution
        Dao dao = Dao(moduleAddress('DAO'));
        dao.paySolutionReward(taskId, solId);
    }
}
