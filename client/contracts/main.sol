pragma solidity ^0.4.11;

contract Module {
    modifier onlyMod(string mod) { require(msg.sender == moduleAddress(mod)); _; }

    address public mainAddress;

    function Module(address mainAddr) { mainAddress = mainAddr; }

    function moduleAddress(string mod) constant internal returns(address addr){
        Main main = Main(mainAddress);
        addr = main.moduleAddresses(mod);
    }
}

contract Main {

    mapping(string => address) public moduleAddresses;
    string[] public moduleNames;
    string public metadata;
    bool public initialized;
    address private creator;

    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }

    function Main(string meta) {
        metadata = meta;
        creator = msg.sender;
    }

    function initializeModuleAddresses(string[] modNames, address[] addrs) {
        require(! initialized);
        require(msg.sender == creator);
        initialized = true;
        moduleNames = modNames;
        for (var i = 0; i < modNames.length; i++) {
            moduleAddresses[modNames[i]] = addrs[i];
        }
    }

    function changeModuleAddress(string modName, address addr, bool isNew) onlyDao {
        moduleAddresses[modName] = addr;
        if (isNew) {
            moduleNames.push(modName);
        }
    }

    function removeModuleAtIndex(uint index) onlyDao {
        delete moduleAddresses[moduleNames[index]];
        delete moduleNames[index];
    }

    function changeMetadata(string meta) onlyDao {
        metadata = meta;
    }

    function() {
        throw;
    }
}
