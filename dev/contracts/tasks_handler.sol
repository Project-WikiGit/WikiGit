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
    enum TaskState { Open, Solved, Invalid }

    struct TaskListing {
        string metadata; //Metadata of the task. Format dependent on the higher level UI.
        address poster;
        uint rewardInWeis;
        uint rewardTokenAmount; //Amount of rewarded tokens
        uint rewardGoodRep; //Reward in good reputation.
        uint penaltyBadRep; //Penalty in bad reputation if a solution is deemed malicious.
        TaskState state;
        uint acceptedSolutionID; //Index of the accepted solution.
        mapping(address => bool) hasUpvoted; //Records whether a team member has upvoted a solution.
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
            Solutions that receives upvote from more than 2/3 of team members will be accepted.
            Solutions that receives downvote from more than 2/3 of team members will be open to penalization.
        */
        uint upvotes;
        uint downvotes;
        mapping(address => bool) hasDownvoted;
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
    uint public rewardTokenCap;

    event TaskSolutionAccepted(uint taskId, uint solutionId, bytes patchIPFSHash);

    function TasksHandler(
        address mainAddr,
        uint _rewardRepCap,
        uint _penaltyRepCap,
        uint _rewardWeiCap,
        uint _rewardTokenCap
    )
        Module(mainAddr)
        public
    {
        //Initialize reward caps
        rewardRepCap = _rewardRepCap;
        penaltyRepCap = _penaltyRepCap;
        rewardWeiCap = _rewardWeiCap;
        rewardTokenCap = _rewardTokenCap;
    }

    function publishTaskListing(
        string _metadata,
        address _poster,
        uint _rewardInWeis,
        uint _rewardTokenAmount,
        uint _rewardGoodRep,
        uint _penaltyBadRep
    )
        public
        needsRight('submit_task')
    {
        //Check if reward exceeds cap
        require(_rewardInWeis <= rewardWeiCap);
        require(_rewardTokenAmount <= rewardTokenCap);
        require(_rewardGoodRep <= rewardRepCap);
        require(_penaltyBadRep <= penaltyRepCap);

        taskList.push(TaskListing({
            metadata: _metadata,
            poster: _poster,
            rewardInWeis: _rewardInWeis,
            rewardTokenAmount: _rewardTokenAmount,
            rewardGoodRep: _rewardGoodRep,
            penaltyBadRep: _penaltyBadRep,
            state: TaskState.Open,
            acceptedSolutionID: 0
        }));
        taskSolutionList.length += 1;
    }

    /*
        For part time contributors who don't have the right to post task listings with rewards.
    */
    function publishRewardlessTaskListing(
        string _metadata,
        address _poster,
        uint _rewardGoodRep,
        uint _penaltyBadRep
    )
        public
        needsRight('submit_task_rewardless')
    {
        require(_rewardGoodRep <= rewardRepCap);
        require(_penaltyBadRep <= penaltyRepCap);

        taskList.push(TaskListing({
            metadata: _metadata,
            poster: _poster,
            rewardInWeis: 0,
            rewardTokenAmount: 0,
            rewardGoodRep: _rewardGoodRep,
            penaltyBadRep: _penaltyBadRep,
            state: TaskState.Open,
            acceptedSolutionID: 0
        }));

        taskSolutionList.length += 1;
    }

    function invalidateTaskListingAtIndex(uint _index) public onlyMod('DAO') {
        require(_index < taskList.length);
        require(taskList[_index].state == TaskState.Open);
        taskList[_index].state = TaskState.Invalid;
    }

    function submitSolution(
        uint _taskId,
        string _metadata,
        bytes _patchIPFSHash
    )
        public
        needsRight('submit_solution')
    {
        require(_taskId < taskList.length);

        TaskListing storage task = taskList[_taskId];

        require(task.state == TaskState.Open);

        if (! task.hasSubmitted[msg.sender]) {
            task.hasSubmitted[msg.sender] = true;
            taskSolutionList[_taskId].push(TaskSolution({
                metadata: _metadata,
                submitter: msg.sender,
                patchIPFSHash: _patchIPFSHash,
                upvotes: 0,
                downvotes: 0
            }));
            taskList[_taskId].memberSolId[msg.sender] = taskSolutionList.length - 1;
        } else {
            uint solId = taskList[_taskId].memberSolId[msg.sender];
            taskSolutionList[_taskId][solId].metadata = _metadata;
            taskSolutionList[_taskId][solId].patchIPFSHash = _patchIPFSHash;
        }
    }

    function voteOnSolution(
        uint _taskId,
        uint _solId,
        bool _isUpvote
    )
        public
        needsRight('vote_solution')
    {
        require(_taskId < taskList.length);
        require(_solId < taskSolutionList[_taskId].length);
        require(taskList[_taskId].state == TaskState.Open);

        if (_isUpvote) {
            TaskListing storage task = taskList[_taskId];
            require(! task.hasUpvoted[msg.sender]);
            sol.upvotes += 1;
        } else {
            TaskSolution storage sol = taskSolutionList[_taskId][_solId];
            require(! sol.hasDownvoted[msg.sender]);
            sol.downvotes += 1;
        }
    }

    /*
        Accepts a solution and pays the rewards to the solution submitter.
    */
    function acceptSolution(uint _taskId, uint _solId) public {
        require(_taskId < taskList.length); //Ensure that taskId is valid.
        TaskListing storage task = taskList[_taskId];
        require(task.state == TaskState.Open);
        require(!task.hasBeenPenalized[taskSolutionList[_taskId][_solId].submitter]);

        require(_solId < taskSolutionList[_taskId].length); //Ensure that solId is valid.
        TaskSolution storage sol = taskSolutionList[_taskId][_solId];

        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(sol.upvotes * 3 >= h.groupMemberCount('team_member') * 2); //At least 2/3 of team members upvoted

        task.state = TaskState.Solved;
        task.acceptedSolutionID = _solId;

        //Broadcast acceptance
        TaskSolutionAccepted(_taskId, _solId, sol.patchIPFSHash);

        //Pay submitter of solution
        Dao dao = Dao(moduleAddress('DAO'));
        dao.paySolutionReward(_taskId, _solId);
    }

    function penalizeSolutionSubmitter(uint _taskId, uint _solId) public {
        require(_solId < taskSolutionList[_taskId].length); //Ensure that solId is valid.
        TaskSolution storage sol = taskSolutionList[_taskId][_solId];

        require(!tHasBeenPenalized(_taskId, sol.submitter));
        setPenalizedStatus(_taskId, sol.submitter, true);

        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(sol.downvotes * 3 >= h.groupMemberCount('team_member') * 2); //At least 2/3 of team members downvoted

        Dao dao = Dao(moduleAddress('DAO'));
        dao.penalizeSolutionSubmitter(_taskId, _solId);
    }

    function setCap(
        string _capType,
        uint _newCap
    )
        public
        onlyMod('DAO')
    {
        if (keccak256(_capType) == keccak256('wei')) {
            rewardWeiCap = _newCap;
        } else if (keccak256(_capType) == keccak256('good_rep')) {
            rewardRepCap = _newCap;
        } else if (keccak256(_capType) == keccak256('bad_rep')) {
            penaltyRepCap = _newCap;
        } else if (keccak256(_capType) == keccak256('token')) {
            rewardTokenCap = _newCap;
        }
    }

    function setPenalizedStatus(uint _taskId, address _memberAddr, bool _status) public onlyMod('DAO') {
        taskList[_taskId].hasBeenPenalized[_memberAddr] = _status;
    }

    //Getters

    function tHasSubmitted(uint _taskId, address _addr) public view returns(bool) {
        return taskList[_taskId].hasSubmitted[_addr];
    }

    function tHasBeenPenalized(uint _taskId, address _addr) public view returns(bool) {
        return taskList[_taskId].hasBeenPenalized[_addr];
    }

    function tMemberSolId(uint _taskId, address _addr) public view returns(uint) {
        return taskList[_taskId].memberSolId[_addr];
    }

    function tHasUpvoted(
        uint _taskId,
        address _addr
    )
        public
        view
        returns(bool)
    {
        return taskList[_taskId].hasUpvoted[_addr];
    }

    function sHasDownvoted(
        uint _taskId,
        uint _solId,
        address _addr
    )
        public
        view
        returns(bool)
    {
        return taskSolutionList[_taskId][_solId].hasDownvoted[_addr];
    }

    //Fallback
    function() public {
        revert();
    }
}
