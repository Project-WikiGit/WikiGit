pragma solidity ^0.4.11;


contract Main {
    mapping(string => address) public moduleAddresses;
    string public metadata;

    modifier onlyDao{ require(msg.sender == moduleAddresses['DAO']); _; }

    function Main(address daoAddr, string meta){
        moduleAddresses['DAO'] = daoAddr;
        metadata = meta;
    }

    function changeModuleAddress(string modName, address addr) onlyDao {
        moduleAddresses[modName] = addr;
    }

    function changeMetadata(string meta) onlyDao {
        metadata = meta;
    }

    function () payable {
        throw;
    }
}
