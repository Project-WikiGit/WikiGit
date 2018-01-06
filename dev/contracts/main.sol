/*
    main.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the main contract of the DAP, or in other words
    the module manager. The main contract records the metadata of the DAP,
    as well as the names and addresses of all modules, including the DAO.
    It is the first contract created when initializing a DAP. Its records
    of the modules is the only place modules look to when trying to communicate
    with other modules, and this centralized index of modules allows individual
    module contracts to be updated down the road, which also means that
    the main contract is the only contract in the DAP that cannot be updated.
*/

pragma solidity ^0.4.18;

contract Module {
    modifier onlyMod(string mod) { require(msg.sender == moduleAddress(mod)); _; }

    address public mainAddress;
    uint public constant decimals = 18;

    function Module(address _mainAddress) public {
        mainAddress = _mainAddress;
    }

    function moduleAddress(string mod) internal view returns(address addr) {
        Main main = Main(mainAddress);
        addr = main.moduleAddresses(keccak256(mod));
    }
}

contract Main {
    mapping(bytes32 => address) public moduleAddresses;
    string[] public moduleNames;
    string public metadata;
    bool public hasInitedAddrs;
    bool public hasInitedABIs;
    address private creator;
    bytes[] public abiIPFSHashes;
    mapping(bytes32 => uint) public abiHashId;

    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }

    function Main(string _metadata, bytes _abiIPFSHash) public {
        metadata = _metadata;
        abiIPFSHashes.push(_abiIPFSHash);
        creator = msg.sender;
    }

    /*
        Used for initializing the module address index. As string[] variables can't be passed as function parameters, the addrs array
        must be ordered in the following way:
        DAO, MEMBER, VAULT, TASKS, GIT, TOKEN
        @param address[] addrs The array that stores the addresses of all initial modules. Must follow the specified format.
    */

    function initializeModuleAddresses(address[] _addrs) public {
        require(!hasInitedAddrs);
        require(msg.sender == creator);
        hasInitedAddrs = true;
        moduleNames = ['DAO', 'MEMBER', 'VAULT', 'TASKS', 'GIT', 'TOKEN'];

        for (uint i = 0; i < moduleNames.length; i++) {
            moduleAddresses[keccak256(moduleNames[i])] = _addrs[i];
        }
    }

    function initializeABIHashForMod(uint _modId, bytes _abiHash) public {
        require(msg.sender == creator);
        require(!hasInitedABIs);

        abiIPFSHashes.push(_abiHash);
        abiHashId[keccak256(moduleNames[_modId])] = abiIPFSHashes.length - 1;

        if (abiIPFSHashes.length >= 7) {
            hasInitedABIs = true;
        }
    }

    function getABIHashForMod(bytes32 _modHash) public view returns(bytes abiHash) {
        return abiIPFSHashes[abiHashId[_modHash]];
    }

    function setABIHashForMod(bytes32 _modHash, bytes _abiHash) public onlyDao {
        abiIPFSHashes[abiHashId[_modHash]] = _abiHash;
    }

    function setModuleAddress(
        string _modName,
        address _addr,
        bool _isNew
    )
        public
        onlyDao
    {
        moduleAddresses[keccak256(_modName)] = _addr;
        if (_isNew) {
            moduleNames.push(_modName);
        }
    }

    function removeModuleAtIndex(uint _index) public onlyDao {
        bytes32 nameHash = keccak256(moduleNames[_index]);
        delete moduleAddresses[nameHash];
        delete moduleNames[_index];
        delete abiIPFSHashes[_index];
        delete abiHashId[nameHash];
    }

    function setMetadata(string _meta) public onlyDao {
        metadata = _meta;
    }

    //Fallback
    function() public {
        revert();
    }
}
