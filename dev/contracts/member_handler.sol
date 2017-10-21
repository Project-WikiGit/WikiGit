/*
    member_handler.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the member manifest and related functions.
*/

pragma solidity ^0.4.11;

import './main.sol';
import './erc20.sol';
import './dao.sol';

contract MemberHandler is Module {
    /*
        Defines a member of the DAO.
    */
    struct Member {
        string userName;
        address userAddress;
        string groupName; //The member group that the member belongs to.
        uint goodRep; //Good reputation
        uint badRep; //Bad reputation
    }

    Member[] public memberList;

    //Should only be used in functions meant to be directly called by members and don't need any rights.
    modifier notBanned { require(!isBanned[msg.sender]); _; }

    //From member address to the index of the member in memberList.
    mapping(address => uint) public memberId;

    /*
        Defines the rights of members in each member group.
        keccak256(groupName) => (keccak256(rightName) => hasRight)
    */
    mapping(bytes32 => mapping(bytes32 => bool)) public groupRights;

    mapping(bytes32 => uint) public groupMemberCount; //Group name's keccak256 hash to member count.

    mapping(address => bool) public isBanned;

    function MemberHandler(string creatorUserName, address mainAddr) Module(mainAddr) {
        //Add msg.sender as member #1
        memberList.push(Member('',0,'',0,0)); //Member at index 0 is reserved, for efficiently checking whether an address has already been registered.
        memberList.push(Member(creatorUserName, msg.sender, 'full_time', 1, 0));
        memberId[msg.sender] = 1;

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
        memberList.push(Member({
            userName: userName,
            userAddress: userAddress,
            groupName: groupName,
            goodRep: goodRep,
            badRep: badRep
        }));
        memberId[userAddress] = memberList.length;
        groupMemberCount[keccak256(groupName)] += 1;
    }

    //Used by shareholders who do not contribute to the project to add themselves into the member list,
    //so that they can vote.
    function setSelfAsPureShareholder(string userName) notBanned {
        require(memberId[msg.sender] == 0); //Ensure user doesn't already exist
        //Check if msg.sender has any voting shares
        Dao dao = Dao(moduleAddress('DAO'));
        bool hasShares;
        for (uint i = 0; i < dao.recognizedTokensCount(); i++) {
            var(,tokenAddress) = dao.recognizedTokenList(i);
            ERC20 token = ERC20(tokenAddress);
            if (token.balanceOf(msg.sender) > 0) {
                hasShares = true;
                break;
            }
        }
        require(hasShares);

        memberId[msg.sender] = memberList.length;
        memberList.push(Member({
            userName: userName,
            userAddress: msg.sender,
            groupName: 'pure_shareholder',
            goodRep: 0,
            badRep: 0
        }));

        groupMemberCount[keccak256('pure_shareholder')] += 1;
    }

    //Used by freelancers to add themselves into the member list so that they can submit task solutions.
    function setSelfAsFreelancer(string userName) notBanned {
        require(memberId[msg.sender] == 0); //Ensure user doesn't already exist

        memberId[msg.sender] = memberList.length;
        memberList.push(Member({
            userName: userName,
            userAddress: msg.sender,
            groupName: 'freelancer',
            goodRep: 0,
            badRep: 0
        }));
    }

    function removeMemberWithAddress(address addr)
        onlyMod('DAO')
    {
        uint index = memberId[addr];
        require(index != 0); //Ensure member exists.

        Member storage member = memberList[index];
        require(keccak256(member.groupName) != keccak256(''));

        groupMemberCount[keccak256(member.groupName)] -= 1;

        delete memberList[index];
        delete memberId[addr];
    }

    function alterBannedStatus(address addr, bool newStatus)
        onlyMod('DAO')
    {
        require(memberId[addr] != 0); //Ensure member exists.

        Member storage member = memberAtAddress(addr);
        if (newStatus && !isBanned[addr]) {
            groupMemberCount[keccak256(member.groupName)] -= 1;
        } else if (!newStatus && isBanned[addr]) {
            groupMemberCount[keccak256(member.groupName)] += 1;
        }
        isBanned[addr] = newStatus;
    }

    function incMemberGoodRep(address addr, uint amount) onlyMod('DAO') {
        require(memberId[addr] != 0); //Ensure member exists.

        Member storage member = memberAtAddress(addr);
        member.goodRep += amount;
    }

    function incMemberBadRep(address addr, uint amount) onlyMod('DAO') {
        require(memberId[addr] != 0); //Ensure member exists.

        Member storage member = memberAtAddress(addr);
        member.badRep += amount;
    }

    function changeMemberGroup(uint id, string newGroupName)
        onlyMod('DAO')
    {
        groupMemberCount[keccak256(memberList[id].groupName)] -= 1;
        groupMemberCount[keccak256(newGroupName)] += 1;
        memberList[id].groupName = newGroupName;
    }

    //Do not confuse with setGroupRight(). This function allows votings to execute setGroupRight().
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

    //Helper functions

    function memberAtAddress(address addr) constant internal returns(Member storage m) {
        m = memberList[memberId[addr]];
    }

    function groupRight(string groupName, string right) constant returns(bool) {
        return groupRights[keccak256(groupName)][keccak256(right)];
    }

    function setGroupRight(string groupName, string right, bool hasRight) internal {
        groupRights[keccak256(groupName)][keccak256(right)] = hasRight;
    }

    function memberHasRight(address addr, string right) constant returns(bool) {
        return groupRight(memberAtAddress(addr).groupName, right);
    }

    function memberGroupNameHash(address addr) constant returns(bytes32) {
        return keccak256(memberAtAddress(addr).groupName);
    }

    function() {
        revert();
    }
}
