pragma solidity ^0.4.11;

contract Module {
    modifier onlyMain { require(msg.sender == moduleAddresses['MAIN']); _; }
    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }
    mapping(string => address) public moduleAddresses;

    function Module() {}

    function moduleAddressChanged(string modName, address newAddr) onlyMain {
        moduleAddresses[modName] = newAddr;
    }
}

contract Main {

    mapping(string => address) public moduleAddresses;
    string[] public moduleNames;
    string public metadata;

    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }

    function Main(address daoAddr, string meta){
        moduleAddresses['DAO'] = daoAddr;
        moduleNames.push('DAO');
        metadata = meta;
    }

    function changeModuleAddress(string modName, address addr, bool isNew) onlyDao {
        moduleAddresses[modName] = addr;
        if (isNew) {
            moduleNames.push(modName);
        }
        for (var i = 0; i < moduleNames.length; i++) {
            Module mod = Module(moduleAddresses[moduleNames[i]]);
            mod.moduleAddressChanged(modName, addr);
        }
    }

    function removeModule(string modName) onlyDao {
        delete moduleAddresses[modName];
        for (var i = 0; i < moduleNames.length; i++) {
            if (moduleNames[i] == modName) {
                delete moduleNames[i];
                break;
            }
        }
    }

    function changeMetadata(string meta) onlyDao {
        metadata = meta;
    }

    function() {
        throw;
    }
}
