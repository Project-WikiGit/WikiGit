pragma solidity ^0.4.11;

import './erc20.sol';
import './vault.sol';
import './tasks_handler.sol';

contract Dao is Module {
    struct Member {
        string userName;
        address userAddress;
        string groupName;
        uint goodRep;
        uint badRep;
    }

    struct VoteToken {
        string name;
        string symbol;
        address tokenAddress;
    }

    struct VotingType {
        string name;
        string description;
        uint quorumPercent;
        uint minForPercent;
        uint goodRepWeight;
        uint badRepWeight;
        mapping(address => uint) tokenWeights; //From token's address to weight
        mapping(bytes32 => bool) isEligible; //From group name's keccak256 hash to bool
    }

    struct Voting {
        string name;
        string description;
        uint typeId;
        address creator;
        uint startBlockNumber;
        uint endBlockNumber;
        uint forVotes;
        uint againstVotes;
        uint votedMemberCount;
        bytes32[] executionHashList;
        address executionActor; //The address of the contract called when executing transaction bytecode.
        mapping(address => bool) hasVoted;
        bool isInvalid;
        bool passed;
    }

    modifier notBanned { require(!isBanned[msg.sender]); _; } //Should be used for functions meant to be directly called by members and don't need any rights.

    modifier needsRight(string right) {
        require(memberHasRight(msg.sender, right));
        require(!isBanned[msg.sender]); //Makes function declarations more concise.
        _;
    }

    Member[] public members;
    mapping(address => uint) public memberId;
    mapping(bytes32 => mapping(bytes32 => bool)) public groupRights;
    mapping(address => bool) public isBanned;

    Voting[] public votings;
    VotingType[] public votingTypes;
    VoteToken[] public acceptedTokens;
    uint public votingMemberCount;


    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);

    //Initializing

    function Dao(string creatorUserName, address mainAddr) Module(mainAddr) {
        //Add msg.sender as member #1
        members.push(Member('',0,'',0,0)); //Member at index 0 is reserved, for efficiently checking whether an address has already been registered.
        members.push(Member(creatorUserName, msg.sender, 'full_time', 1, 0));
        memberId[msg.sender] = 1;
        votingMemberCount = 1;

        //Initialize group rights
        //Full time contributor rights
        setGroupRight('full_time', 'create_voting', true);
        setGroupRight('full_time', 'submit_task', true);
        setGroupRight('full_time', 'submit_task_rewardless', true);
        setGroupRight('full_time', 'vote', true);
        setGroupRight('full_time', 'submit_solution', true);
        //setGroupRight('full_time', 'accept_Solution', true);
        setGroupRight('full_time', 'vote_solution', true);
        setGroupRight('full_time', 'access_proj_management', true);

        //Part time contributor rights
        setGroupRight('part_time', 'create_voting', true);
        setGroupRight('part_time', 'submit_task_rewardless', true);
        setGroupRight('part_time', 'vote', true);
        setGroupRight('part_time', 'submit_solution', true);
        setGroupRight('part_time', 'vote_solution', true);
        setGroupRight('part_time', 'access_proj_management', true);

        //Freelancer rights
        setGroupRight('freelancer', 'submit_solution', true);

        //Pure shareholder (shareholder who doesn't contribute) rights
        setGroupRight('pure_shareholder', 'vote', true);
        setGroupRight('pure_shareholder', 'create_voting', true);

        //Initialize voting types
        votingTypes.push(VotingType({
            name: 'Default Voting Type',
            description: 'Default voting type used for bootstrapping the DAO. Only full time contributors can vote. Passing a vote requires unanimous support. Should be removed after bootstrapping. Adding new members before finishing bootstrapping is not advised.',
            quorumPercent: 100,
            minForPercent: 100,
            goodRepWeight: 1,
            badRepWeight: 1
        }));
        votingTypes[votingTypes.length - 1].isEligible[keccak256('full_time')] = true;
    }

    //Voting

    function createVoting(
        string name,
        string description,
        uint votingTypeId,
        uint startBlockNumber,
        uint endBlockNumber,
        bytes32[] executionHashList,
        address executionActor
    )
        needsRight('create_voting')
    {
        require(keccak256(votingTypes[votingTypeId].name) != keccak256(''));

        votings.push(Voting({
            name: name,
            description: description,
            typeId: votingTypeId,
            creator: msg.sender,
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber,
            executionHashList: executionHashList,
            executionActor: executionActor,
            forVotes: 0,
            againstVotes: 0,
            votedMemberCount: 0,
            isInvalid: false,
            passed:false
        }));

        VotingCreated(votings.length - 1);
    }

    function invalidateVotingAtIndex(uint index) onlyMod('DAO') {
        require(index < votings.length);

        votings[index].isInvalid = true;
    }

    function vote(uint votingId, bool support) needsRight('vote') {
        Voting storage voting = votings[votingId];

        VotingType storage vType = votingTypes[voting.typeId];
        Member storage member = members[memberId[msg.sender]];

        require(!voting.isInvalid);
        require(block.number >= voting.startBlockNumber && block.number < voting.endBlockNumber);
        require(!voting.hasVoted[msg.sender]);
        require(vType.isEligible[keccak256(memberAtAddress(msg.sender).groupName)]);

        voting.hasVoted[msg.sender] = true;

        int memberVotes = int(vType.goodRepWeight * member.goodRep) - int(vType.badRepWeight * member.badRep);
        for (uint i = 0; i < acceptedTokens.length; i++) {
            VoteToken storage t = acceptedTokens[i];
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
        Voting storage voting = votings[votingId];
        require(!voting.isInvalid);
        voting.isInvalid = true;

        VotingType storage vType = votingTypes[voting.typeId];
        require(block.number >= voting.endBlockNumber);

        voting.passed = (voting.forVotes / (voting.forVotes + voting.againstVotes) * 100 >= vType.minForPercent)
                        && (voting.votedMemberCount / votingMemberCount * 100 >= vType.quorumPercent);
        VotingConcluded(votingId, voting.passed);
    }

    function executeVoting(uint votingId, uint bytecodeHashId, bytes executionBytecode) needsRight('vote') {
        Voting storage voting = votings[votingId];
        require(voting.passed);
        require(voting.executionHashList[bytecodeHashId] == keccak256(executionBytecode));

        voting.executionActor.call(executionBytecode);
        delete voting.executionHashList[bytecodeHashId];
    }

    function createVotingType(
        string name,
        string description,
        bytes32[] votableGroups,
        uint quorumPercent,
        uint minForPercent,
        uint goodRepWeight,
        uint badRepWeight,
        address[] tokenAddresses,
        uint[] tokenWeights
    )
        onlyMod('DAO')
    {
        require(tokenAddresses.length == tokenWeights.length);

        pushNewVotingType(
            name,
            description,
            quorumPercent,
            minForPercent,
            goodRepWeight,
            badRepWeight
        );

        for (uint i = 0; i < votableGroups.length; i++) {
            votingTypes[votingTypes.length - 1].isEligible[votableGroups[i]] = true;
        }

        for (i = 0; i < tokenAddresses.length; i++) {
            address addr = tokenAddresses[i];
            uint weight = tokenWeights[i];
            votingTypes[votingTypes.length - 1].tokenWeights[addr] = weight;
        }
    }

    function pushNewVotingType(
        string name,
        string description,
        uint quorumPercent,
        uint minForPercent,
        uint goodRepWeight,
        uint badRepWeight
    )
        internal
    {
        votingTypes.push(VotingType({
            name: name,
            description: description,
            quorumPercent: quorumPercent,
            minForPercent: minForPercent,
            goodRepWeight: goodRepWeight,
            badRepWeight: badRepWeight
        }));
    }

    function removeVotingTypeAtIndex(uint index) onlyMod('DAO')
    {
        delete votingTypes[index];
    }

    //Vote token functions

    function addAcceptedToken(
        string name,
        string symbol,
        address tokenAddress,
        uint rewardTokenCap
    )
        onlyMod('DAO')
    {
        acceptedTokens.push(VoteToken({
            name: name,
            symbol: symbol,
            tokenAddress: tokenAddress
        }));

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.setCap('token', rewardTokenCap, tokenAddress);
    }

    function removeAcceptedTokenAtIndex(uint index) onlyMod('DAO')
    {
        require(index < acceptedTokens.length);

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.deleteRewardTokenCap(acceptedTokens[index].tokenAddress);

        delete acceptedTokens[index];
    }

    //Member functions

    function addMember(
        string userName,
        address userAddress,
        string groupName,
        uint goodRep,
        uint badRep
    )
        onlyMod('DAO')
    {
        require(memberId[userAddress] == 0); //Prevent altering existing members. ID 0 is reserved for creator.
        members.push(Member({
            userName: userName,
            userAddress: userAddress,
            groupName: groupName,
            goodRep: goodRep,
            badRep: badRep
        }));
        memberId[userAddress] = members.length;
        if (groupRight(groupName, 'vote')) {
            votingMemberCount += 1;
        }
    }

    function setSelfAsPureShareholder(string userName) notBanned {
        //Check if msg.sender has any voting shares
        bool hasShares;
        for (uint i = 0; i < acceptedTokens.length; i++) {
            ERC20 token = ERC20(acceptedTokens[i].tokenAddress);
            if (token.balanceOf(msg.sender) > 0) {
                hasShares = true;
                break;
            }
        }
        require(hasShares);
        members.push(Member({
            userName: userName,
            userAddress: msg.sender,
            groupName: 'pure_shareholder',
            goodRep: 0,
            badRep: 0
        }));
        memberId[msg.sender] = members.length;
        votingMemberCount += 1;
    }

    function setSelfAsFreelancer(string userName) notBanned {
        require(memberId[msg.sender] == 0); //Ensure user doesn't already exist
        members.push(Member({
            userName: userName,
            userAddress: msg.sender,
            groupName: 'freelancer',
            goodRep: 0,
            badRep: 0
        }));
        memberId[msg.sender] = members.length;
    }

    function removeMemberWithAddress(address addr)
        onlyMod('DAO')
    {
        uint index = memberId[addr];
        require(0 < index);

        Member storage member = members[index];
        require(keccak256(member.groupName) != keccak256(''));

        if (groupRight(member.groupName, 'vote')) {
            votingMemberCount -= 1;
        }
        delete members[index];
        delete memberId[addr];
    }

    function alterBannedStatus(address addr, bool newStatus)
        onlyMod('DAO')
    {
        require(memberId[addr] != 0);
        isBanned[addr] = newStatus;
    }

    function changeMemberGroup(uint id, string newGroupName)
        onlyMod('DAO')
    {
        bool prevVoteRight = groupRight(members[id].groupName, 'vote');
        bool currVoteRight = groupRight(newGroupName, 'vote');

        if (prevVoteRight && ! currVoteRight) {
            votingMemberCount -= 1;
        } else if (! prevVoteRight && currVoteRight) {
            votingMemberCount += 1;
        }

        members[id].groupName = newGroupName;
    }

    function setRightOfGroup(string groupName, string rightName, bool hasRight)
        onlyMod('DAO')
    {
        setGroupRight(groupName, rightName, hasRight);
    }

    function changeSelfName(string newName) notBanned {
        require(keccak256(memberAtAddress(msg.sender).groupName) != keccak256(''));
        memberAtAddress(msg.sender).userName = newName;
    }

    function changeSelfAddress(address newAddress) notBanned {
        require(keccak256(memberAtAddress(msg.sender).groupName) != keccak256(''));
        memberAtAddress(msg.sender).userAddress = newAddress;
        memberId[newAddress] = memberId[msg.sender];
        memberId[msg.sender] = 0;
    }

    function paySolutionReward(uint taskId, uint solId) onlyMod('TASKS') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (_,,rewardInWeis, rewardGoodRep,) = handler.tasks(taskId);
        var (__,submitter,) = handler.taskSolutions(taskId, solId);

        //Reward in ether
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingWithdrawl(rewardInWeis, submitter, true);

        //Reward in reputation
        memberAtAddress(submitter).goodRep += rewardGoodRep;

        //Reward in tokens
        for (uint i = 0; i < handler.rewardTokenCount(taskId); i++) {
            uint id = handler.rewardTokenIndex(taskId, i);
            uint reward = handler.rewardTokenAmount(taskId, i);

            VoteToken storage token = acceptedTokens[id];

            vault.addPendingTokenWithdrawl(reward, submitter, token.symbol, token.tokenAddress, true);
        }
    }

    function penalizeSolutionSubmitter(uint taskId, uint solId, bool banSubmitter)
        onlyMod('DAO')
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        var (,,,, penaltyBadRep,) = handler.tasks(taskId);
        var (_,submitter,) = handler.taskSolutions(taskId, solId);

        //Check if submitter has already been penalized
        require(!handler.hasBeenPenalizedForTask(taskId, submitter));
        handler.setPenalizedStatus(taskId, submitter, true);

        //Penalize reputation
        memberAtAddress(submitter).badRep += penaltyBadRep;

        if (banSubmitter) {
            isBanned[submitter] = true;
        }
    }

    //Helpers

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }

    function groupRight(string groupName, string right) constant returns(bool) {
        return groupRights[keccak256(groupName)][keccak256(right)];
    }

    function setGroupRight(string groupName, string right, bool hasRight) private {
        groupRights[keccak256(groupName)][keccak256(right)] = hasRight;
    }

    function memberHasRight(address addr, string right) returns(bool) {
        return groupRight(memberAtAddress(addr).groupName, right);
    }

    function() {
        revert();
    }
}
