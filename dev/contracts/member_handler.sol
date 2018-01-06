/*
    member_handler.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the member manifest and related functions.
*/

pragma solidity ^0.4.18;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './main.sol';
import './dao.sol';
import './token.sol';

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

    //Should only be used in functions meant to be directly called by members and don't need any rights.
    modifier notBanned { require(!isBanned[msg.sender]); _; }

    uint public memberCount;

    Member[] public memberList;

    //From member address to the index of the member in memberList.
    mapping(address => uint) public memberId;

    /*
        Defines the rights of members in each member group.
        keccak256(groupName) => (keccak256(rightName) => hasRight)
    */
    mapping(bytes32 => mapping(bytes32 => bool)) public groupRights;

    mapping(bytes32 => uint) public groupMemberCount; //Group name's keccak256 hash to member count.

    mapping(address => bool) public isBanned;

    function MemberHandler(string _creatorUserName, address _mainAddr) Module(_mainAddr) public {
        memberList.push(Member('',0,'',0,0)); //Member at index 0 is reserved, for efficiently checking whether an address has already been registered.

        //Add msg.sender as member #1
        memberList.push(Member(_creatorUserName, msg.sender, 'team_member', 1, 0));
        memberId[msg.sender] = 1;
        memberCount += 1;
        groupMemberCount[keccak256('team_member')] += 1;

        //Initialize group rights
        //Team member rights
        setGroupRight('team_member', 'create_voting', true);
        setGroupRight('team_member', 'submit_task', true);
        setGroupRight('team_member', 'submit_task_rewardless', true);
        setGroupRight('team_member', 'vote', true);
        setGroupRight('team_member', 'quorum_include', true);
        setGroupRight('team_member', 'submit_solution', true);
        setGroupRight('team_member', 'vote_solution', true);
        setGroupRight('team_member', 'accept_hash', true);

        //Part time contributor rights
        setGroupRight('contributor', 'create_voting', true);
        setGroupRight('contributor', 'submit_task_rewardless', true);
        setGroupRight('contributor', 'vote', true);
        setGroupRight('contributor', 'submit_solution', true);

        //Pure shareholder (shareholder who doesn't contribute) rights
        setGroupRight('pure_shareholder', 'vote', true);
        setGroupRight('pure_shareholder', 'create_voting', true);
    }

    //Member functions

    function addMember(
        string _userName,
        address _userAddress,
        string _groupName,
        uint _goodRep,
        uint _badRep
    )
        public
        onlyMod('DAO')
    {
        require(memberId[_userAddress] == 0); //Prevent altering existing members. ID 0 is reserved for creator.
        memberList.push(Member({
            userName: _userName,
            userAddress: _userAddress,
            groupName: _groupName,
            goodRep: _goodRep,
            badRep: _badRep
        }));
        memberId[_userAddress] = memberList.length - 1;
        memberCount += 1;
        groupMemberCount[keccak256(_groupName)] += 1;
    }

    //Used by freelancers to add themselves into the member list so that they can submit task solutions.
    function setSelfAsContributor(string userName) public notBanned {
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

    //Used by shareholders who do not contribute to the project to add themselves into the member list,
    //so that they can vote.
    function setSelfAsPureShareholder(string _userName) public notBanned {
        require(memberId[msg.sender] == 0); //Ensure user doesn't already exist
        //Check if msg.sender has any voting shares
        Token token = Token(moduleAddress('TOKEN'));
        require(token.balanceOf(msg.sender) > 0);

        memberId[msg.sender] = memberList.length;
        memberList.push(Member({
            userName: _userName,
            userAddress: msg.sender,
            groupName: 'pure_shareholder',
            goodRep: 0,
            badRep: 0
        }));

        memberCount += 1;
        groupMemberCount[keccak256('pure_shareholder')] += 1;
    }

    function removeMemberWithAddress(address _addr) public onlyMod('DAO') {
        uint index = memberId[_addr];
        require(index != 0); //Ensure member exists.

        Member storage member = memberList[index];
        require(keccak256(member.groupName) != keccak256(''));

        memberCount -= 1;
        groupMemberCount[keccak256(member.groupName)] -= 1;

        delete memberList[index];
        delete memberId[_addr];
    }

    function alterBannedStatus(address _addr, bool _newStatus) public onlyMod('DAO') {
        require(memberId[_addr] != 0); //Ensure member exists.

        Member storage member = getMemberAtAddress(_addr);
        if (_newStatus && !isBanned[_addr]) {
            groupMemberCount[keccak256(member.groupName)] -= 1;
        } else if (!_newStatus && isBanned[_addr]) {
            groupMemberCount[keccak256(member.groupName)] += 1;
        }
        isBanned[_addr] = _newStatus;
    }

    function incMemberGoodRep(address _addr, uint _amount) public onlyMod('DAO') {
        require(memberId[_addr] != 0); //Ensure member exists.

        Member storage member = getMemberAtAddress(_addr);
        member.goodRep += _amount;
    }

    function incMemberBadRep(address _addr, uint _amount) public onlyMod('DAO') {
        require(memberId[_addr] != 0); //Ensure member exists.

        Member storage member = getMemberAtAddress(_addr);
        member.badRep += _amount;
    }

    function changeMemberGroup(uint _id, string _newGroupName) public onlyMod('DAO') {
        groupMemberCount[keccak256(memberList[_id].groupName)] -= 1;
        groupMemberCount[keccak256(_newGroupName)] += 1;
        memberList[_id].groupName = _newGroupName;
    }

    function changeSelfName(string _newName) public notBanned {
        require(keccak256(getMemberAtAddress(msg.sender).groupName) != keccak256(''));
        getMemberAtAddress(msg.sender).userName = _newName;
    }

    function changeSelfAddress(address _newAddress) public notBanned {
        require(keccak256(getMemberAtAddress(msg.sender).groupName) != keccak256(''));
        getMemberAtAddress(msg.sender).userAddress = _newAddress;
        memberId[_newAddress] = memberId[msg.sender];
        memberId[msg.sender] = 0;
    }

    //Do not confuse with setGroupRight(). This function allows votings to execute setGroupRight().
    function setRightOfGroup(
        string groupName,
        string rightName,
        bool hasRight
    )
        public
        onlyMod('DAO')
    {
        setGroupRight(groupName, rightName, hasRight);
    }

    //Getters

    function getMemberAtAddress(address _addr) internal view  returns(Member storage) {
        return memberList[memberId[_addr]];
    }

    function getGroupRight(string _groupName, string _right) public view returns(bool) {
        return groupRights[keccak256(_groupName)][keccak256(_right)];
    }

    function memberHasRight(address _addr, string _right) public view returns(bool) {
        return getGroupRight(getMemberAtAddress(_addr).groupName, _right);
    }

    function memberGroupNameHash(address _addr) public view returns(bytes32) {
        return keccak256(getMemberAtAddress(_addr).groupName);
    }

    function getMemberListCount() public view returns(uint) {
        return memberList.length;
    }

    //Setters

    //Do not confuse with setRightOfGroup(). This is an internal helper function.
    function setGroupRight(
        string _groupName,
        string _right,
        bool _hasRight
    )
        internal
    {
        groupRights[keccak256(_groupName)][keccak256(_right)] = _hasRight;
    }

    //Fallback
    function() public {
        revert();
    }
}
