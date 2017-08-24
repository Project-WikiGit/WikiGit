pragma solidity ^0.4.11;

import './erc20.sol';
import './vault.sol';

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
        Execution[] executionList;
        mapping(address => bool) hasVoted;
    }

    struct Execution {
        function (var[], bytes32) func;
        var[] args;
    }

    modifier needsRight(string right) {
        require(groupRights[memberAtAddress(msg.sender).groupName][right]);
        _;
    }

    modifier needsSanction(function(var[], bytes32) func,
        var[] args,
        bytes32 sanction
    ) {
        require(sanctions[sanction]);
        require(sanction == keccak256(func, args, msg.sender));
        sanctions[sanction] = false;
        _;
    }

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

    function Dao(string creatorUserName) Module() {
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

    function changeModuleAddress(var[] args, bytes32 sanction)
        private
        needsSanction(changeModuleAddress, args, sanction)
    {
        Main main = Main(mainAddress);
        string modName = args[0];
        address newAddr = args[1];
        bool isNew = args[2];
        main.changeModuleAddress(modName, newAddr, isNew);
    }

    function removeModule(var[] args, bytes32 sanction)
        private
        needsSanction(removeModule, args, sanction)
    {
        Main main = Main(mainAddress);
        uint modIndex = args[0];
        main.removeModuleAtIndex(modIndex);
    }

    function changeMetadata(var[] args, bytes32 sanction)
        private
        needsSanction(changeMetadata, args, sanction)
    {
        Main main = Main(mainAddress);
        string newMeta = args[0];
        main.changeMetadata(newMeta);
    }

    //Voting

    function createVoting(
        string name,
        string description,
        uint votingTypeId,
        uint startBlockNumber,
        uint endBlockNumber,
        function (var[], bytes32)[] execFuncList,
        var[][] execArgsList
    )
        needsRight('create_voting')
    {
        Execution[] execList;
        for (var i = 0; i < execFuncList.length; i++) {
            execList.push(Execution({
                func: execFuncList[i],
                args: execArgsList[i]
            }));
        }
        Voting voting = Voting({
            name: name,
            description: description,
            type: votingTypes[votingTypeId],
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber,
            executionList: execList
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
        for (uint i = 0; i < acceptedTokens.length; i++) {
            VotingToken t = acceptedTokens[i];
            ERC20 token = ERC20(t.tokenAddress);
            memberVotes += type.tokenWeights[t.symbol] * token.balanceOf(msg.sender);
        }
        if (support) {
            voting.forVotes += memberVotes;
        } else {
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
        if (passed) {
            //Execute voting
            Execution[] execList = voting.executionList;
            for (var i = 0; i < execList.length; i++) {
                function (var[], bytes32) execFunc = execList[i].func;
                var[] execArgs = execList[i].args;
                bytes32 sanction = keccak256(execFunc, execArgs, msg.sender);
                sanctions[sanction] = true;
                execFunc(execArgs, sanction);
            }
        }
        VotingConcluded(votingId, passed);
    }

    //Member functions

    function addMember(var[] args, bytes32 sanction)
        private
        needsSanction(addMember, args, sanction)
    {
        members.push(Member({
            userName: args[0],
            userAddress: args[1],
            groupName: args[2],
            goodRep: args[3],
            badRep: args[4]
        }));
        if (groupRights[args[2]]['vote']) {
            votingMemberCount += 1;
        }
    }

    function changeMemberGroup(var[] args, bytes32 sanction)
        private
        needsSanction(changeMemberGroup, args, sanction)
    {
        uint id = args[0];
        string newGroupName = args[1];
        bool prevVoteRight = groupRights[members[id].groupName]['vote'];
        bool currVoteRight = groupRights[newGroupName]['vote'];

        if (prevVoteRight && ! currVoteRight) {
            votingMemberCount -= 1;
        } else if (! prevVoteRight && currVoteRight) {
            votingMemberCount += 1;
        }

        members[id].groupName = newGroupName;
    }

    function setRightOfGroup(var[] args, bytes32 sanction)
        private
        needsSanction(setRightsOfGroup, args, sanction)
    {
        string groupName = args[0];
        string rightName = args[1];
        bool hasRight = args[2];
        groupRights[groupName][rightName] = hasRight;
    }

    function changeMemberName(string newName) {
        memberAtAddress(msg.sender).name = newName;
    }

    function changeMemberAddress(address newAddress) {
        memberAtAddress(msg.sender).userAddress = newAddress;
    }

    //Vault manipulator functions

    function withdrawFromVault(var[] args, bytes32 sanction)
        private
        needsSanction(withDrawFromVault, args, sanction)
    {
        uint amountInWeis = args[0];
        address to = args[1];
        Vault vault = Vault(vaultAddress());
        vault.withdraw(amountInWeis, to);
    }

    function addPayBehavior(var[] args, bytes32 sanction)
        private
        needsSanction(addPayBehavior, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        PayBehavior behavior = PayBehavior(args[0], args[1], args[2], args[3]);
        vault.addPayBehavior(behavior);
    }

    function removePayBehavior(var[] args, bytes32 sanction)
        private
        needsSanction(removePayBehavior, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        PayBehavior behavior = PayBehavior({
            multiplier: args[0],
            oracleAddress: args[1],
            tokenAddress: args[2],
            untilBlockiNumber: args[3]
        });
        vault.removePayBehavior(behavior);
    }

    function removePayBehaviorAtIndex(var[] args, bytes32 sanction)
        private
        needsSanction(removePayBehaviorAtIndex, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        vault.removePayBehaviorAtIndex(args[0]);
    }

    function removeAllPayBehaviors(var[] args, bytes32 sanction)
        private
        needsSanction(removeAllPayBehaviors, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        vault.removeAllPayBehaviors();
    }

    function exportToVault(var[] args, bytes32 sanction)
        private
        needsSanction(exportToVault, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        address newAddr = args[0];
        bool burn = args[1];
        vault.exportToVault(newAddr, burn);
        Main main = Main(mainAddress);
        main.changeModuleAddress('VAULT', newAddr, false);
    }

    //Helper functions

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }

    function vaultAddress() constant internal returns(address addr) {
        Main main = Main(mainAddress);
        addr = main.moduleAddresses['VAULT'];
    }

    function() {
        throw;
    }
}
