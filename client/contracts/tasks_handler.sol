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

    uint public rewardRepCap;
    uint public penaltyRepCap;
    uint public rewardWeiCap;
    mapping(bytes32 => uint) public rewardTokenCap; //From token symbol to cap

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
        require(rewardInWeis <= rewardWeiCap);
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);
        require(rewardTokenAmountList.length == rewardTokenIndexList.length);

        for (uint i = 0; i < rewardTokenIndexList.length; i++) {
            uint id = rewardTokenIndexList[i];
            uint reward = rewardTokenAmountList[i];
            require(reward <= rewardTokenCap[acceptedTokens[id].symbol]);
        }

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

    function paySolutionReward(uint taskId, uint solId) private {
        TaskListing task = tasks[taskId];
        TaskSolution sol = taskSolutions[taskId][solId];

        //Reward in ether
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingWithdrawl(task.rewardInWeis, sol.submitter, rewardFreezeTime);

        //Reward in reputation
        Member member = memberAtAddress(sol.submitter);
        member.goodRep += task.rewardGoodRep;

        //Reward in tokens
        for (uint i = 0; i < task.rewardTokenIndexList.length; i++) {
            uint id = task.rewardTokenIndexList[i];
            uint reward = task.rewardTokenAmountList[i];

            VoteToken token = acceptedTokens[id];

            vault.addPendingTokenWithdrawl(reward, sol.submitter, token.symbol, token.tokenAddress, rewardFreezeTime);
        }
    }

    function penalizeSolutionSubmitter(var[] args, bytes32 sanction)
        private
        needsSanction(penalizeSolutionSubmitter, args, sanction)
    {
        uint taskId = args[0];
        uint solId = args[1];
        bool banSubmitter = args[2];

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        TaskListing task = handler.tasks(taskId);
        TaskSolution sol = task.solutions(solId);

        //Check if submitter has already been penalized
        require(!task.hasBeenPenalized[sol.submitter]);
        task.hasBeenPenalized[sol.submitter] = true;

        //Penalize reputation
        Member member = memberAtAddress(sol.submitter);
        member.badRep += task.penaltyBadRep;

        if (banSubmitter) {
            isBanned[sol.submitter] = true;
        }
    }

    function setCap(string capType, uint newCap, string tokenSymbol)
        onlyMod('DAO')
    {
        if (capType == 'wei') {
            rewardWeiCap = newCap;
        } else if (capType == 'good_rep') {
            rewardRepCap = newCap;
        } else if (capType == 'bad_rep') {
            penaltyRepCap = newCap;
        } else if (capType == 'token') {
            rewardTokenCap[keccak256(tokenSymbol)] = newCap;
        }
    }

    function() {
        revert();
    }
}
