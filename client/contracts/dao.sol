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
    }

    Member[] public members;
    mapping(string => mapping(string => bool)) public groupRights;

    function Dao(string creatorUserName){
        members.push(Member(creatorUserName, msg.sender, 'full_time'));
        groupRights['full_time']['create_voting'] = true;
    }
}
