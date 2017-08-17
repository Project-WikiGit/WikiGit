pragma solidity ^0.4.11;

import './erc20.sol';

contract Dao {
    struct Member {
        string userName;
        address userAddress;
        string groupName;
    }

    struct VoteToken {
        string name;
        address tokenAddress;
    }

    struct VotingType {
        string name;
        string description;
        string[] votableGroups;
        uint quorumPercent;
        uint minVotesToPass;
    }

    struct Voting {
        string name;
        string description;
        VotingType type;
        uint untilBlockNumber;
        mapping(address => bool) hasVoted;
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

    //Initializing

    function Dao(string creatorUserName) {
        members.push(Member(creatorUserName, msg.sender, 'creator'));
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
    }

    //Voting

    function createVoting(Voting voting) needsRight('create_voting') {
        votings.push(voting);
    }

    //Helper functions

    function memberAtAddress(address addr) constant internal returns(Member m) {
        m = members[memberId[addr]];
    }

    function () payable {
        throw;
    }
}
