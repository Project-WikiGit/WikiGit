pragma solidity ^0.4.11;

contract Module {
    modifier onlyMod(string mod) { require(msg.sender == moduleAddress(mod)); _; }

    address public mainAddress;

    function Module(address mainAddr) { mainAddress = mainAddr; }

    function moduleAddress(string mod) constant internal returns(address addr){
        Main main = Main(mainAddress);
        addr = main.moduleAddresses(keccak256(mod));
    }
}

contract Main {

    mapping(bytes32 => address) public moduleAddresses;
    string[] public moduleNames;
    string public metadata;
    bool public initialized;
    address private creator;

    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }

    function Main(string meta) {
        metadata = meta;
        creator = msg.sender;
    }

    /*
        Used for initializing the module address index. As string[] variables can't be passed as function parameters, the addrs array
        must be ordered in the following way:
        DAO, VAULT, TASKS, GIT
        @param addrs The array that stores the addresses of all initial modules. Must follow the specified format.
    */

    function initializeModuleAddresses(address[] addrs) {
        require(! initialized);
        require(msg.sender == creator);
        initialized = true;
        moduleNames = ['DAO', 'VAULT', 'TASKS', 'GIT'];
        for (uint i = 0; i < moduleNames.length; i++) {
            moduleAddresses[keccak256(moduleNames[i])] = addrs[i];
        }
    }

    function changeModuleAddress(string modName, address addr, bool isNew) onlyDao {
        moduleAddresses[keccak256(modName)] = addr;
        if (isNew) {
            moduleNames.push(modName);
        }
    }

    function removeModuleAtIndex(uint index) onlyDao {
        delete moduleAddresses[keccak256(moduleNames[index])];
        delete moduleNames[index];
    }

    function changeMetadata(string meta) onlyDao {
        metadata = meta;
    }

    function() {
        revert();
    }
}
