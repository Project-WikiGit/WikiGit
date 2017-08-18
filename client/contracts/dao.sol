pragma solidity ^0.4.11;

import './erc20.sol';

contract Dao {
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
        string[] votableGroups;
        uint quorumPercent;
        uint minForPercent;
        int goodRepWeight;
        int badRepWeight;
        mapping(string => int) tokenWeights;
    }

    struct Voting {
        string name;
        string description;
        VotingType type;
        uint startBlockNumber;
        uint endBlockNumber;
        uint forVotes;
        uint againstVotes;
        uint votedMemberCount;
        Execution execution;
        mapping(address => bool) hasVoted;
    }

    struct Execution {
        function (var[], bytes32) func;
        var[] arguments;
    }

    modifier needsRight(string right) {
        require(groupRights[memberAtAddress(msg.sender).groupName][right]);
        _;
    }

    address public mainAddress;
    Member[] public members;
    mapping(address => uint) public memberId;
    mapping(string => mapping(string => bool)) public groupRights;

    Voting[] public votings;
    VotingType[] public votingTypes;
    VoteToken[] public acceptedTokens;
    uint public votingMemberCount;
    mapping(bytes32 => bool) private sanctions;

    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);


    //Initializing

    function Dao(string creatorUserName) {
        members.push(Member(creatorUserName, msg.sender, 'creator', 0, 0));
        memberId[msg.sender] = 0;
        groupRights['creator']['set_main_address'] = true;

        groupRights['full_time']['create_voting'] = true;
        groupRights['full_time']['submit_task'] = true;
        groupRights['full_time']['submit_task_rewardless'] = true;
        groupRights['full_time']['vote'] = true;
        groupRights['full_time']['submit_solution'] = true;
        groupRights['full_time']['accept_solution'] = true;
        groupRights['full_time']['access_proj_management'] = true;

        groupRights['part_time']['create_voting'] = true;
        groupRights['part_time']['submit_task_rewardless'] = true;
        groupRights['part_time']['vote'] = true;
        groupRights['part_time']['submit_solution'] = true;
        groupRights['part_time']['access_proj_management'] = true;

        groupRights['free_lancer']['submit_solution'] = true;
    }

    function setMainAddress(address mainAddr) needsRight('set_main_address') {
        groupRights[memberAtAddress(msg.sender).groupName]['set_main_address'] = false;
        mainAddress = mainAddr;
        members[memberId[msg.sender]].groupName = 'full_time';
        votingMemberCount = 1;
    }

    //Voting

    function createVoting(
        string name,
        string description,
        uint votingTypeId,
        uint startBlockNumber,
        uint endBlockNumber,
        function (var[], bytes32) execFunc,
        var[] execArgs
    ) needsRight('create_voting') {
        Voting voting = Voting({
            name: name,
            description: description,
            type: votingTypes[votingTypeId],
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber,
            execution: Execution(execFunc, execArgs)
        });
        votings.push(voting);
        VotingCreated(votings.length - 1);
    }

    function vote(uint votingId, bool support) needsRight('vote') {
        Voting voting = votings[votingId];
        VotingType type = voting.type;
        Member member = members[memberId[msg.sender]];
        require(block.number >= voting.startBlockNumber && block.number < voting.endBlockNumber);
        require(!voting.hasVoted[msg.sender]);
        require(type.votableGroups[memberAtAddress(msg.sender).group]);
        voting.hasVoted[msg.sender] = true;
        int memberVotes = type.goodRepWeight * member.goodRep + type.badRepWeight * member.badRep;
        for(uint i = 0; i < acceptedTokens.length; i++) {
            VotingToken t = acceptedTokens[i];
            ERC20 token = ERC20(t.tokenAddress);
            memberVotes += type.tokenWeights[t.symbol] * token.balanceOf(msg.sender);
        }
        if(support) {
            voting.forVotes += memberVotes;
        }
        else {
            voting.againstVotes += memberVotes;
        }
        voting.votedMemberCount += 1;
    }

    function concludeVoting(uint votingId) needsRight('vote') {
        Voting voting = votings[votingId];
        VotingType type = voting.type;
        require(block.number >= voting.endBlockNumber);
        bool passed = (voting.forVotes / (voting.forVotes + voting.againstVotes) * 100 >= type.minForPercent)
                        && (voting.votedMemberCount / votingMemberCount * 100 >= type.quorumPercent);
        if(passed) {
            //Execute voting
            function (var[], bytes32) execFunc = voting.execution.func;
            var[] execArgs = voting.execution.arguments;
            bytes32 sanction = keccak256(execFunc, execArgs, msg.sender, block.number);
            sanctions[sanction] = true;
            execFunc(execArgs, sanction);
        }
        VotingConcluded(votingId, passed);
    }

    //Member functions

    function addMember(var[] args, bytes32 sanction) private {
        require(sanctions[sanction]);
        require(sanction == keccak256(addMember, args, msg.sender, block.number));
        sanctions[sanction] = false;
    }

    function changeMemberGroup(var[] args, bytes32 sanction) private {

    }

    function changeMemberName(string newName) {
        memberAtAddress(msg.sender).name = newName;
    }

    function changeMemberAddress(address newAddress) {
        memberAtAddress(msg.sender).userAddress = newAddress;
    }

    function setRightOfGroup(var[] args, bytes32 sanction) private {
        require(sanctions[sanction]);
        require(sanction == keccak256(setRightOfGroup, args, msg.sender, block.number));
        sanctions[sanction] = false;
    }

    //Helper functions

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }

    function () payable {
        throw;
    }
}
