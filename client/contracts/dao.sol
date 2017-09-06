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

    struct Execution {
        function (var[], bytes32) func;
        var[] args;
    }

    modifier notBanned { require(!isBanned[msg.sender]); _; } //Should be used for functions meant to be directly called by members and don't need any rights.

    modifier needsRight(string right) {
        require(groupRights[memberAtAddress(msg.sender).groupName][right]);
        require(!isBanned[msg.sender]); //Makes function declarations more concise.
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
    mapping(address => bool) public isBanned;

    Voting[] public votings;
    VotingType[] public votingTypes;
    VoteToken[] public acceptedTokens;
    uint public votingMemberCount;
    mapping(bytes32 => bool) public sanctions;

    uint public rewardRepCap;
    uint public penaltyRepCap;
    uint public rewardWeiCap;
    mapping(string => uint) public rewardTokenCap; //From token symbol to cap

    uint public rewardFreezeTime;
    uint public withdrawlFreezeTime;

    event VotingCreated(uint votingId);
    event VotingConcluded(uint votingId, bool passed);

    //Initializing

    function Dao(string creatorUserName, address mainAddr) Module(mainAddr) {
        //Add msg.sender as member #1
        members.push(Member()); //Member at index 0 is reserved, for efficiently checking
        members.push(Member(creatorUserName, msg.sender, 'full_time', 1, 0));
        memberId[msg.sender] = 1;
        votingMemberCount = 1;

        //Initialize group rights
        //Full time contributor rights
        groupRights['full_time']['create_voting'] = true;
        groupRights['full_time']['submit_task'] = true;
        groupRights['full_time']['submit_task_rewardless'] = true;
        groupRights['full_time']['vote'] = true;
        groupRights['full_time']['submit_solution'] = true;
        groupRights['full_time']['accept_solution'] = true;
        groupRights['full_time']['vote_solution'] = true;
        groupRights['full_time']['access_proj_management'] = true;

        //Part time contributor rights
        groupRights['part_time']['create_voting'] = true;
        groupRights['part_time']['submit_task_rewardless'] = true;
        groupRights['part_time']['vote'] = true;
        groupRights['part_time']['submit_solution'] = true;
        groupRights['full_time']['vote_solution'] = true;
        groupRights['part_time']['access_proj_management'] = true;

        //Freelancer rights
        groupRights['freelancer']['submit_solution'] = true;

        //Pure shareholder (shareholder who doesn't contribute) rights
        groupRights['pure_shareholder']['vote'] = true;
        groupRights['pure_shareholder']['create_voting'] = true;

        //Initialize voting types
        VotingType defaultType = VotingType({
            name: 'Default Voting Type',
            description: 'Default voting type used for bootstrapping the DAO. Only full time contributors can vote. Passing a vote requires unanimous support. Should be removed after bootstrapping. Adding new members before finishing bootstrapping is not advised.',
            votableGroups: ['full_time'],
            quorumPercent: 100,
            minForPercent: 100,
            goodRepWeight: 1,
            badRepWeight: -1
        });
        votingTypes.push(defaultType);

        //Initialize reward caps
        rewardRepCap = 3;
        penaltyRepCap = 6;
        rewardWeiCap = 1 ether;
        defaultRewardTokenCap = 10 ** 18;

        //Initialize withdrawl freeze times
        rewardFreezeTime = 3524; //Roughly 24 hours
        withdrawlFreezeTime = 147; //Roughly 1 hour
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

    //Member functions

    function addMember(var[] args, bytes32 sanction)
        private
        needsSanction(addMember, args, sanction)
    {
        require(memberId[args[1]] == 0); //Prevent altering existing members. ID 0 is reserved for creator.
        members.push(Member({
            userName: args[0],
            userAddress: args[1],
            groupName: args[2],
            goodRep: args[3],
            badRep: args[4]
        }));
        memberId[args[1]] = members.length;
        if (groupRights[args[2]]['vote']) {
            votingMemberCount += 1;
        }
    }

    function setSelfAsPureShareholder(string userName) {
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
            groupName: 'pure_shareholder'
        }));
        memberId[msg.sender] = members.length;
        votingMemberCount += 1;
    }

    function setSelfAsFreelancer(string userName) {
        require(memberId[msg.sender] == 0); //Ensure user doesn't already exist
        members.push(Member({
            userName: userName,
            userAddress: msg.sender,
            groupName: 'freelancer'
        }));
        memberId[msg.sender] = members.length;
    }

    function removeMemberWithAddress(var[] args, bytes32 sanction)
        private
        needsSanction(removeMember, args, sanction)
    {
        uint index = memberId[args[0]];
        require(0 < index < members.length);

        Member member = members[index];
        require(member.groupName != '');

        if (groupRights[member.groupName]['vote']) {
            votingMemberCount -= 1;
        }
        delete members[index];
        delete memberId[args[0]];
    }

    function alterBannedStatus(var[] args, bytes32 sanction)
        private
        needsSanction(banMemberWithAddress, args, sanction)
    {
        address addr = args[0];
        require(memberId[addr] != 0);

        bool newStatus = args[1];
        isBanned[addr] = status;
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

    function changeSelfName(string newName) notBanned {
        require(memberAtAddress(msg.sender).groupName != '');
        memberAtAddress(msg.sender).name = newName;
    }

    function changeSelfAddress(address newAddress) notBanned {
        require(memberAtAddress(msg.sender).groupName != '');
        memberAtAddress(msg.sender).userAddress = newAddress;
    }

    //Vault manipulator functions

    function addPendingWithdrawl(var[] args, bytes32 sanction)
        private
        needsSanction(addPendingWithdrawl, args, sanction)
    {
        uint amountInWeis = args[0];
        address to = args[1];
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingWithdrawl(amountInWeis, to, withdrawlFreezeTime);
    }

    function addPendingTokenWithdrawl(var[] args, bytes32 sanction)
        private
        needsSanction(addPendingTokenWithdrawl, args, sanction)
    {
        uint amount = args[0];
        address to = args[1];
        string symbol = args[2];
        address tokenAddr = args[3];
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.addPendingTokenWithdrawl(amountInWeis, to, symbol, tokenAddr, withdrawlFreezeTime);
    }

    function invalidatePendingWithdrawl(var[] args, bytes32 sanction)
        private
        needsSanction(invalidatePendingWithdrawl, args, sanction)
    {
        uint id = args[0];
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.invalidatePendingWithdrawl(id);
    }

    function invalidatePendingTokenWithdrawl(var[] args, bytes32 sanction)
        private
        needsSanction(invalidatePendingTokenWithdrawl, args, sanction)
    {
        uint id = args[0];
        Vault vault = Vault(moduleAddress('VAULT'));
        vault.invalidatePendingTokenWithdrawl(id);
    }

    function changeWithdrawlFreezeTime(var[] args, bytes32 sanction)
        private
        needsSanction(changeWithdrawlFreezeTime, args, sanction)
    {
        withdrawlFreezeTime = args[0];
    }

    function changeRewardFreezeTime(var[] args, bytes32 sanction)
        private
        needsSanction(changeRewardFreezeTime, args, sanction)
    {
        rewardFreezeTime = args[0];
    }

    function addPayBehavior(var[] args, bytes32 sanction)
        private
        needsSanction(addPayBehavior, args, sanction)
    {
        Vault vault = Vault(vaultAddress());
        PayBehavior behavior = PayBehavior({
            multiplier: args[0],
            oracleAddress: args[1],
            tokenAddress: args[2],
            startBlockNumber: args[3],
            endBlockNumber: args[4]
        });
        vault.addPayBehavior(behavior);
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

    //Tasks functions

    function publishTaskListing(
        string metadata,
        uint rewardInWeis,
        uint[] rewardTokenIndexList,
        uint[] rewardTokenAmountList,
        uint rewardGoodRep,
        uint penaltyBadRep
    )
        needsRight('submit_task')
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));

        require(rewardInWeis <= rewardWeiCap);
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);
        require(rewardTokenAmountList.length == rewardTokenIndexList.length);

        for (uint i = 0; i < rewardTokenIndexList.length; i++) {
            uint id = rewardTokenIndexList[i];
            uint reward = rewardTokenAmountList[i];
            require(reward <= rewardTokenCap[acceptedTokens[id].symbol]);
        }

        handler.publishTaskListing(
            metadata,
            rewardInWeis,
            rewardTokenIndexList,
            rewardTokenAmountList,
            rewardGoodRep,
            penaltyBadRep
        );
    }

    function publishRewardlessTaskListing(
        string metadata,
        uint rewardGoodRep,
        uint penaltyBadRep
    )
        needsRight('submit_task_rewardless')
    {
        require(rewardGoodRep <= rewardRepCap);
        require(penaltyBadRep <= penaltyRepCap);

        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.publishTaskListing(
            metadata,
            0,
            new uint[](0),
            new uint[](0),
            rewardGoodRep,
            penaltyBadRep
        );
    }

    function invalidateTaskListingAtIndex(var[] args, bytes32 sanction)
        private
        needsSanction(invalidateTaskListingAtIndex, args, sanction)
    {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.invalidateTaskListingAtIndex(args[0]);
    }

    function submitSolution(string metadata, uint taskId, bytes patchData) needsRight('submit_solution') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.submitSolution(msg.sender, metadata, taskId, patchData);
    }

    function voteOnTaskSolution(uint taskId, uint solId, bool isUpvote) needsRight('vote_solution') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.voteOnSolution(msg.sender, taskId, solId, isUpvote);
    }

    function acceptSolution(uint taskId, uint solId) needsRight('accept_solution') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        handler.acceptSolution(msg.sender, taskId, solId);
    }

    function paySolutionReward(uint taskId, uint solId) onlyMod('TASKS') {
        TasksHandler handler = TasksHandler(moduleAddress('TASKS'));
        TaskListing task = handler.tasks(taskId);
        TaskSolution sol = task.solutions(solId);

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

    function setCap(var[] args, bytes32 sanction)
        private
        needsSanction(setRewardWeiCap, args, sanction)
    {
        string capType = args[0];
        uint newCap = args[1];
        if (capType == 'wei') {
            rewardWeiCap = newCap;
        } else if (capType == 'good_rep') {
            rewardRepCap = newCap;
        } else if (capType == 'bad_rep') {
            penaltyRepCap = newCap;
        } else if (capType == 'token') {
            string tokenSymbol = args[2];
            rewardTokenCap[tokenSymbol] = newCap;
        }
    }

    //Helpers

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }

    function() {
        revert();
    }
}
