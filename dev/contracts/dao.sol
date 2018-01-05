/*
    dao.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the mechanics of the DAO, including managing members,
    holding votings, modifying the bylaws and structure of the DAO, calling and
    managing other modules, allowing modules to access other modules, and so on.

    The DAO is the absolute source of power of the entire DAP.
*/

pragma solidity ^0.4.18;

import './token.sol';
import './vault.sol';
import './tasks_handler.sol';
import './member_handler.sol';

contract Dao is Module {
    struct Voting {
        string name;
        string description;
        address creator;
        uint startBlockNumber;
        uint forVotes;
        uint againstVotes;
        uint votedMemberCount;
        bytes32 executionHash; //The hash of the transaction bytecode that is executed after the voting is passed.
        address executionTarget; //The address that the transaction would be sent to.
        mapping(address => bool) hasVoted;
        bool isInvalid;
        bool isPassed;
    }

    modifier notBanned {
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(! h.isBanned(msg.sender));
        _;
     }
    //Should only be used in functions meant to be directly called by members and don't need any rights.

    modifier needsRight(string right) {
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        require(h.memberHasRight(msg.sender, right));
        require(! h.isBanned(msg.sender)); //Makes function declarations more concise.
        _;
    }

    //Voting session parameters
    uint public quorumPercent; //Decimal (ex. 34.567%)
    uint public minForPercent; //Minimum proportion of for votes needed to pass the voting. Decimal.
    uint public activeTimeInBlocks; //The number of blocks for which the voting is active.
    uint public goodRepWeight; //Decimal
    uint public badRepWeight; //Decimal
    uint public tokenWeight; //Decimal

    Voting[] public votingList;

    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);

    //Initializing

    function Dao(
        address _mainAddr,
        uint _quorumPercent,
        uint _minForPercent,
        uint _activeTimeInBlocks,
        uint _goodRepWeight,
        uint _badRepWeight,
        uint _tokenWeight
    )
        Module(_mainAddr)
        public
    {
        quorumPercent = _quorumPercent;
        minForPercent = _minForPercent;
        activeTimeInBlocks = _activeTimeInBlocks;
        goodRepWeight = _goodRepWeight;
        badRepWeight = _badRepWeight;
        tokenWeight = _tokenWeight;
    }

    //Voting

    function createVoting(
        string _name,
        string _description,
        uint _startBlockNumber,
        bytes32 _executionHash,
        address _executionTarget
    )
        public
        needsRight('create_voting')
    {
        votingList.push(Voting({
            name: _name,
            description: _description,
            creator: msg.sender,
            startBlockNumber: _startBlockNumber,
            executionHash: _executionHash,
            executionTarget: _executionTarget,
            forVotes: 0,
            againstVotes: 0,
            votedMemberCount: 0,
            isInvalid: false,
            isPassed:false
        }));

        VotingCreated(votingList.length - 1);
    }

    function invalidateVotingAtIndex(uint _index) public onlyMod('DAO') {
        require(_index < votingList.length);

        votingList[_index].isInvalid = true;
    }

    function vote(uint _votingId, bool _support) public needsRight('vote') {
        Voting storage voting = votingList[_votingId];

        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        var (,goodRep, badRep) = h.memberList(h.memberId(msg.sender));

        require(!voting.isInvalid);
        require(block.number >= voting.startBlockNumber && block.number < voting.startBlockNumber + activeTimeInBlocks);
        require(!voting.hasVoted[msg.sender]);

        voting.hasVoted[msg.sender] = true;

        //Only team members count towards quorum
        if (h.memberHasRight(msg.sender, 'quorum_include')) {
            voting.votedMemberCount += 1;
        }

        int memberVotes = int(goodRepWeight * goodRep / 10**decimals) - int(badRepWeight * badRep / 10**decimals);
        Token token = Token(moduleAddress('TOKEN'));
        memberVotes += int(tokenWeight * token.balanceOf(msg.sender) / 10**(2 * decimals));

        if (memberVotes < 0) {
            memberVotes = 0;
        }

        if (_support) {
            voting.forVotes += uint(memberVotes);
        } else {
            voting.againstVotes += uint(memberVotes);
        }
    }

    function concludeVoting(uint _votingId) public needsRight('vote') {
        Voting storage voting = votingList[_votingId];
        require(!voting.isInvalid);
        voting.isInvalid = true;

        require(block.number >= voting.startBlockNumber + activeTimeInBlocks);

        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));

        uint teamMemberCount = h.groupMemberCount(keccak256('team_member'));

        voting.isPassed = (voting.forVotes * 100 * 10**decimals / (voting.forVotes + voting.againstVotes) >= minForPercent)
                        && (voting.votedMemberCount * 100 * 10**decimals / teamMemberCount >= quorumPercent);
        VotingConcluded(_votingId, voting.isPassed);
    }

    function executeVoting(
        uint _votingId,
        bytes _executionBytecode
    )
        public
        needsRight('vote')
    {
        Voting storage voting = votingList[_votingId];
        require(voting.isPassed);
        require(voting.executionHash == keccak256(_executionBytecode));

        if (!voting.executionTarget.call(_executionBytecode)) revert();
    }

    function paySolutionReward(uint _taskId, uint _solId) public onlyMod('TASKS') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (_,,rewardInWeis, rewardTokenAmount, rewardGoodRep,) = handler.taskList(_taskId);
        var (__,submitter,) = handler.taskSolutionList(_taskId, _solId);

        //Reward in ether
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingWithdrawl(rewardInWeis, submitter, true, true);

        //Reward in reputation
        paySolutionRewardGoodRep(submitter, rewardGoodRep);

        //Reward in tokens
        vault.addPendingWithdrawl(rewardTokenAmount, submitter, true, false);
    }

    //Split out as an independent function to prevent StackTooDeep error
    function paySolutionRewardGoodRep(address _submitter, uint _rewardGoodRep) internal {
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        h.incMemberGoodRep(_submitter, _rewardGoodRep);
    }

    /*
        Used for penalizing malicious solution submitters.
    */
    function penalizeSolutionSubmitter(
        uint _taskId,
        uint _solId
    )
        public
        onlyMod('TASKS')
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (_,,,, penaltyBadRep,) = handler.taskList(_taskId);
        var (__,submitter,) = handler.taskSolutionList(_taskId, _solId);

        //Penalize reputation
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        h.incMemberBadRep(submitter, penaltyBadRep);
    }

    //Getters

    function getVotingListCount() public view returns(uint) {
        return votingList.length;
    }

    function vHasVoted(uint _votingId, address _addr) public view returns(bool) {
        return votingList[_votingId].hasVoted[_addr];
    }

    //Fallback
    function() public {
        revert();
    }
}
