pragma solidity ^0.4.11;


contract Dao {
    struct Member {
        string userName;
        address userAddress;
        string groupName;
    }

    Member[] public members;
    mapping(string => mapping(string => bool)) public groupRights;

    function Dao(string creatorUserName){
        members.push(Member(creatorUserName, msg.sender, 'full_time'));
        groupRights['full_time']['vote'] = true;
    }
}
