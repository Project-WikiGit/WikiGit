/*
    dao.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the mechanics of the DAO, including managing members,
    holding votings, modifying the bylaws and structure of the DAO, calling and
    managing other modules, allowing modules to access other modules, and so on.

    The DAO is the absolute source of power of the entire DAP.
*/

pragma solidity ^0.4.11;

import './erc20.sol';
import './vault.sol';
import './tasks_handler.sol';
import './member_handler.sol';

contract Dao is Module {
    /*
        Defines an ERC20 token recognized by the DAO.
    */
    struct RecognizedToken {
        string name;
        string symbol;
        address tokenAddress;
    }

    /*
        Defines a certain type of voting.
        The weights are the linear coefficients for talleying the votes.
    */
    struct VotingType {
        string name;
        string description;
        uint quorumPercent;
        uint minForPercent; //Minimum proportion of for votes needed to pass the voting.
        uint activeTimeInBlocks; //The number of blocks for which the voting is active.
        uint goodRepWeight;
        uint badRepWeight;
        mapping(address => uint) tokenWeights; //From token's address to weight
        mapping(bytes32 => bool) isEligible; //From group name's keccak256 hash to bool. For checking whether a group is allowed to vote.
        bytes32[] votableGroups; //Array of the hashes of the names of the member groups that are allowed to vote.
    }

    struct Voting {
        string name;
        string description;
        uint typeId; //The index of the voting type in the votingTypeList array.
        address creator;
        uint startBlockNumber;
        uint forVotes;
        uint againstVotes;
        uint votedMemberCount;
        bytes32[] executionHashList; //The list of hashes of the transaction bytecodes that are executed after the voting is passed.
        address executionActor; //The address of the contract called when executing transaction bytecode.
        mapping(address => bool) hasVoted;
        bool isInvalid;
        bool passed;
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

    Voting[] public votingList;
    VotingType[] public votingTypeList;
    RecognizedToken[] public recognizedTokenList;


    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);

    //Initializing

    function Dao(string creatorUserName, address mainAddr) Module(mainAddr) {
        bytes32[] storage votableGroups;
        votableGroups.push(keccak256('full_time'));

        //Initialize voting types
        votingTypeList.push(VotingType({
            name: 'Default Voting Type',
            description: 'Default voting type used for bootstrapping the DAO. Only full time contributors can vote. Passing a vote requires unanimous support. Should be removed after bootstrapping. Adding new members before finishing bootstrapping is not advised.',
            quorumPercent: 100,
            minForPercent: 100,
            activeTimeInBlocks: 25,
            goodRepWeight: 1,
            badRepWeight: 1,
            votableGroups: votableGroups
        }));
        votingTypeList[votingTypeList.length - 1].isEligible[keccak256('full_time')] = true;
    }

    //Voting

    function createVoting(
        string name,
        string description,
        uint votingTypeId,
        uint startBlockNumber,
        bytes32[] executionHashList,
        address executionActor
    )
        needsRight('create_voting')
    {
        require(keccak256(votingTypeList[votingTypeId].name) != keccak256(''));

        votingList.push(Voting({
            name: name,
            description: description,
            typeId: votingTypeId,
            creator: msg.sender,
            startBlockNumber: startBlockNumber,
            executionHashList: executionHashList,
            executionActor: executionActor,
            forVotes: 0,
            againstVotes: 0,
            votedMemberCount: 0,
            isInvalid: false,
            passed:false
        }));

        VotingCreated(votingList.length - 1);
    }

    function invalidateVotingAtIndex(uint index) onlyMod('DAO') {
        require(index < votingList.length);

        votingList[index].isInvalid = true;
    }

    function vote(uint votingId, bool support) needsRight('vote') {
        Voting storage voting = votingList[votingId];
        VotingType storage vType = votingTypeList[voting.typeId];

        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        Member storage member = h.memberAtAddress(msg.sender);

        require(!voting.isInvalid);
        require(block.number >= voting.startBlockNumber && block.number < voting.startBlockNumber + vType.activeTimeInBlocks);
        require(!voting.hasVoted[msg.sender]);
        require(vType.isEligible[keccak256(memberAtAddress(msg.sender).groupName)]);

        voting.hasVoted[msg.sender] = true;

        int memberVotes = int(vType.goodRepWeight * member.goodRep) - int(vType.badRepWeight * member.badRep);
        for (uint i = 0; i < recognizedTokenList.length; i++) {
            RecognizedToken storage t = recognizedTokenList[i];
            ERC20 token = ERC20(t.tokenAddress);
            memberVotes += int(vType.tokenWeights[t.tokenAddress] * token.balanceOf(msg.sender));
        }
        if (memberVotes < 0) {
            memberVotes = 0;
        }
        if (support) {
            voting.forVotes += uint(memberVotes);
        } else {
            voting.againstVotes += uint(memberVotes);
        }
        voting.votedMemberCount += 1;
    }

    function concludeVoting(uint votingId) needsRight('vote') {
        Voting storage voting = votingList[votingId];
        require(!voting.isInvalid);
        voting.isInvalid = true;

        VotingType storage vType = votingTypeList[voting.typeId];
        require(block.number >= voting.startBlockNumber + vType.activeTimeInBlocks);

        uint votingMemberCount;
        for (uint i = 0; i < vType.votableGroups.length; i++) {
            votingMemberCount += groupMemberCount[vType.votableGroups[i]];
        }

        voting.passed = (voting.forVotes / (voting.forVotes + voting.againstVotes) * 100 >= vType.minForPercent)
                        && (voting.votedMemberCount / votingMemberCount * 100 >= vType.quorumPercent);
        VotingConcluded(votingId, voting.passed);
    }

    function executeVoting(uint votingId, uint bytecodeHashId, bytes executionBytecode) needsRight('vote') {
        Voting storage voting = votingList[votingId];
        require(voting.passed);
        require(voting.executionHashList[bytecodeHashId] == keccak256(executionBytecode));

        voting.executionActor.call(executionBytecode);
        delete voting.executionHashList[bytecodeHashId];
    }

    function createVotingType(
        string name,
        string description,
        uint quorumPercent,
        uint minForPercent,
        uint activeTimeInBlocks,
        uint goodRepWeight,
        uint badRepWeight,
        address[] tokenAddresses,
        uint[] tokenWeights,
        bytes32[] votableGroups
    )
        onlyMod('DAO')
    {
        require(tokenAddresses.length == tokenWeights.length);

        pushNewVotingType(
            name,
            description,
            quorumPercent,
            minForPercent,
            activeTimeInBlocks,
            goodRepWeight,
            badRepWeight,
            votableGroups
        );

        for (uint i = 0; i < votableGroups.length; i++) {
            votingTypeList[votingTypeList.length - 1].isEligible[votableGroups[i]] = true;
        }

        setVotingTypeTokenWeights(tokenAddresses, tokenWeights);
    }

    function pushNewVotingType(
        string name,
        string description,
        uint quorumPercent,
        uint minForPercent,
        uint activeTimeInBlocks,
        uint goodRepWeight,
        uint badRepWeight,
        bytes32[] votableGroups
    )
        internal
    {
        votingTypeList.push(VotingType({
            name: name,
            description: description,
            quorumPercent: quorumPercent,
            minForPercent: minForPercent,
            activeTimeInBlocks: activeTimeInBlocks,
            goodRepWeight: goodRepWeight,
            badRepWeight: badRepWeight,
            votableGroups: votableGroups
        }));
    }

    function setVotingTypeTokenWeights(address[] tokenAddresses, uint[] tokenWeights) internal {
        for (uint i = 0; i < tokenAddresses.length; i++) {
            address addr = tokenAddresses[i];
            uint weight = tokenWeights[i];
            votingTypeList[votingTypeList.length - 1].tokenWeights[addr] = weight;
        }
    }

    function removeVotingTypeAtIndex(uint index) onlyMod('DAO')
    {
        delete votingTypeList[index];
    }

    //Token functions

    function addRecognizedToken(
        string name,
        string symbol,
        address tokenAddress,
        uint rewardTokenCap
    )
        onlyMod('DAO')
    {
        recognizedTokenList.push(RecognizedToken({
            name: name,
            symbol: symbol,
            tokenAddress: tokenAddress
        }));

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.setCap('token', rewardTokenCap, tokenAddress);
    }

    function removeRecognizedTokenAtIndex(uint index) onlyMod('DAO')
    {
        require(index < recognizedTokenList.length);

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.deleteRewardTokenCap(recognizedTokenList[index].tokenAddress);

        delete recognizedTokenList[index];
    }

    function paySolutionReward(uint taskId, uint solId) onlyMod('TASKS') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (_,,rewardInWeis, rewardGoodRep,) = handler.taskList(taskId);
        var (__,submitter,) = handler.taskSolutionList(taskId, solId);

        //Reward in ether
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingWithdrawl(rewardInWeis, submitter, true);

        //Reward in reputation
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        h.incMemberGoodRep(rewardGoodRep);

        //Reward in tokens
        for (uint i = 0; i < handler.rewardTokenCount(taskId); i++) {
            uint id = handler.rewardTokenIndex(taskId, i);
            uint reward = handler.rewardTokenAmount(taskId, i);

            RecognizedToken storage token = recognizedTokenList[id];

            vault.addPendingTokenWithdrawl(reward, submitter, token.symbol, token.tokenAddress, true);
        }
    }

    /*
        Used for penalizing malicious solution submitters.
    */
    function penalizeSolutionSubmitter(uint taskId, uint solId, bool banSubmitter)
        onlyMod('DAO')
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (_,,,, penaltyBadRep,) = handler.taskList(taskId);
        var (__,submitter,) = handler.taskSolutionList(taskId, solId);

        //Check if submitter has already been penalized
        require(!handler.hasBeenPenalizedForTask(taskId, submitter));
        handler.setPenalizedStatus(taskId, submitter, true);

        //Penalize reputation
        MemberHandler h = MemberHandler(moduleAddress('MEMBER'));
        h.incMemberBadRep(penaltyBadRep);

        if (banSubmitter) {
            h.alterBannedStatus(submitter, true);
        }
    }
}
