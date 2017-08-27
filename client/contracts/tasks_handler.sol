pragma solidity ^0.4.0;

import './main.sol';

contract TasksHandler is Module {

    struct TaskListing {
        string metadata;
        address poster;
        uint rewardInWeis;
        string[] rewardTokenSymbolList;
        uint[] rewardInTokensList;
        uint rewardGoodRep;
        uint penaltyBadRep;
    }

    TaskListing[] public tasks;

    function TasksHandler(address mainAddr) Module(mainAddr) {

    }

    function publishTaskListing(TaskListing task) onlyMod('DAO') {
        tasks.push(task);
    }

}
