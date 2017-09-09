pragma solidity ^0.4.11

import './main.sol'

contract MembersHandler is Module{
    struct Member {
        string userName;
        address userAddress;
        string groupName;
        uint goodRep;
        uint badRep;
    }

    Member[] public members;
    mapping(address => uint) public memberId;
    mapping(bytes32 => mapping(bytes32 => bool)) public groupRights;
    mapping(address => bool) public isBanned;

    function MembersHandler(address mainAddr) Module(mainAddr) {
        //Add msg.sender as member #1
        members.push(Member()); //Member at index 0 is reserved, for efficiently checking
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
        setGroupRight('full_time', 'accept_Solution', true);
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
        setGroupRight(groupName, rightName, hasRight);
    }

    function groupRight(string groupName, string right) returns(bool) {
        return groupRights[keccak256(groupName)][keccak256(right)];
    }

    function setGroupRight(string groupName, string right, bool hasRight) private {
        groupRights[keccak256(groupName)][keccak256(right)] = hasRight;
    }

    function changeSelfName(string newName) notBanned {
        require(memberAtAddress(msg.sender).groupName != '');
        memberAtAddress(msg.sender).name = newName;
    }

    function changeSelfAddress(address newAddress) notBanned {
        require(memberAtAddress(msg.sender).groupName != '');
        memberAtAddress(msg.sender).userAddress = newAddress;
    }

    //Helpers

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }
}
