pragma solidity ^0.4.11;

import './erc20.sol';
import './vault.sol';
import './tasks_handler.sol';

contract Dao is Module {
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
        mapping(string => int) tokenWeights; //From token symbol to weight
    }

    struct Voting {
        string name;
        string description;
        VotingType vType;
        address creator;
        uint startBlockNumber;
        uint endBlockNumber;
        uint forVotes;
        uint againstVotes;
        uint votedMemberCount;
        Execution[] executionList;
        mapping(address => bool) hasVoted;
        bool isInvalid;
    }

    modifier notBanned { require(!isBanned[msg.sender]); _; } //Should be used for functions meant to be directly called by members and don't need any rights.

    modifier needsRight(string right) {
        require(groupRights[keccak256(memberAtAddress(msg.sender).groupName)][keccak256(right)]);
        require(!isBanned[msg.sender]); //Makes function declarations more concise.
        _;
    }

    Voting[] public votings;
    VotingType[] public votingTypes;
    VoteToken[] public acceptedTokens;
    uint public votingMemberCount;



    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);

    //Initializing

    function Dao(string creatorUserName, address mainAddr) Module(mainAddr) {


        //Initialize voting types
        votingTypes.push(VotingType({
            name: 'Default Voting Type',
            description: 'Default voting type used for bootstrapping the DAO. Only full time contributors can vote. Passing a vote requires unanimous support. Should be removed after bootstrapping. Adding new members before finishing bootstrapping is not advised.',
            votableGroups: ['full_time'],
            quorumPercent: 100,
            minForPercent: 100,
            goodRepWeight: 1,
            badRepWeight: -1
        }));


    }

    function importFromPrevDao() onlyMod('DAO') {
        Dao prev = Dao(moduleAddress('DAO'));
        members = prev.members;
        memberId = prev.memberId;
        groupRights = prev.groupRights;
        votings = prev.votings;
        votingTypes = prev.votingTypes;
        acceptedTokens = prev.acceptedTokens;
        votingMemberCount = prev.votingMemberCount;
        sanctions = prev.sanctions;
    }

    function exportToNewDao(var[] args, bytes32 sanction)
        private
        needsSanction(exportToNewDao, args, sanction)
    {
        address newAddr = args[0];
        Dao next = Dao(newAddr);
        next.importFromPrevDao();
    }

    //Module management

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
        require(execFuncList.length == execArgsList.length);
        for (uint i = 0; i < execFuncList.length; i++) {
            execList.push(Execution({
                func: execFuncList[i],
                args: execArgsList[i]
            }));
        }

        require(votingTypes[votingTypeId].name != '');
        Voting voting = Voting({
            name: name,
            description: description,
            vType: votingTypes[votingTypeId],
            creator: msg.sender,
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber,
            executionList: execList
        });
        votings.push(voting);

        VotingCreated(votings.length - 1);
    }

    function invalidateVotingAtIndex(var[] args, bytes32 sanction)
        private
        needsSanction(invalidateVotingAtIndex, args, sanction)
    {
        uint index = args[0];
        require(index < votings.length);

        Voting voting = votings[index];
        voting.isInvalid = true;
    }

    function vote(uint votingId, bool support) needsRight('vote') {
        Voting voting = votings[votingId];

        VotingType type = voting.vType;
        Member member = members[memberId[msg.sender]];

        require(!voting.isInvalid);
        require(block.number >= voting.startBlockNumber && block.number < voting.endBlockNumber);
        require(!voting.hasVoted[msg.sender]);
        require(type.votableGroups[memberAtAddress(msg.sender).group]);

        voting.hasVoted[msg.sender] = true;

        //WikiGit employs square root voting
        int memberVotes = type.goodRepWeight * member.goodRep ** 0.5 + type.badRepWeight * member.badRep ** 0.5;
        for (uint i = 0; i < acceptedTokens.length; i++) {
            VotingToken t = acceptedTokens[i];
            ERC20 token = ERC20(t.tokenAddress);
            memberVotes += type.tokenWeights[t.symbol] * token.balanceOf(msg.sender) ** 0.5;
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
        require(!voting.isInvalid);
        voting.isInvalid = true;

        VotingType type = voting.vType;
        require(block.number >= voting.endBlockNumber);

        bool passed = (voting.forVotes / (voting.forVotes + voting.againstVotes) * 100 >= type.minForPercent)
                        && (voting.votedMemberCount / votingMemberCount * 100 >= type.quorumPercent);
        if (passed) {
            //Execute voting
            Execution[] execList = voting.executionList;
            for (uint i = 0; i < execList.length; i++) {
                function (var[], bytes32) execFunc = execList[i].func;
                var[] execArgs = execList[i].args;
                bytes32 sanction = keccak256(execFunc, execArgs, msg.sender);
                sanctions[sanction] = true;
                execFunc(execArgs, sanction);
            }
        }
        VotingConcluded(votingId, passed);
    }

    function createVotingType(var[] args, bytes32 sanction)
        private
        needsSanction(createVotingType, args, sanction)
    {
        VotingType vType = VotingType({
            name: args[0],
            description: args[1],
            votableGroups: args[2],
            quorumPercent: args[3],
            minForPercent: args[4],
            goodRepWeight: args[5],
            badRepWeight: args[6]
        });
        string[] tokenSymbols = args[7];
        uint[] tokenWeights = args[8];
        for (uint i = 0; i < tokenSymbols.length; i++) {
            string symbol = tokenSymbols[i];
            uint weight = tokenWeights[i];
            vType.tokenWeights[symbol] = weight;
        }
        votingTypes.push(vType);
    }

    function removeVotingTypeAtIndex(var[] args, bytes32 sanction)
        private
        needsSanction(removeVotingType, args, sanction)
    {
        delete votingTypes[args[0]];
    }

    //Vote token functions

    function addAcceptedToken(var[] args, bytes32 sanction)
        private
        needsSanction(addAcceptedToken, args, sanction)
    {
        VoteToken token = VoteToken({
            name: args[0],
            symbol: args[1],
            tokenAddress: args[2]
        });
        acceptedTokens.push(token);
        rewardTokenCap[args[1]] = args[3];
    }

    function removeAcceptedTokenAtIndex(var[] args, bytes32 sanction)
        private
        needsSanction(removeAcceptedTokenAtIndex, args, sanction)
    {
        uint index = args[0];
        require(index < acceptedTokens.length);
        delete rewardTokenCap[acceptedTokens[index].symbol];
        delete acceptedTokens[index];
    }

    function() {
        revert();
    }
}
