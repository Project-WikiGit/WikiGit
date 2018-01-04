pragma solidity ^0.4.18;

import './main.sol';

contract Database is Module {
    struct UStruct {
        uint[] uints;
        string[] strings;
        bool[] bools;
        address[] addresses;
        bytes[] bytesList;
        bytes32[] bytes32s;
        mapping(address => uint)[] address2Uints;
        mapping(address => bool)[] address2Bools;
    }

    mapping(bytes32 => uint) uints;
    mapping(bytes32 => string) strings;
    mapping(bytes32 => bool) bools;
    mapping(bytes32 => address) addresses;
    mapping(bytes32 => bytes) bytesList;
    mapping(bytes32 => bytes32) bytes32s;
    mapping(bytes32 => mapping(uint => uint)) uint2Uints;
    mapping(bytes32 => mapping(address => uint)) address2Uints;
    mapping(bytes32 => mapping(bytes32 => mapping(bytes32 => bool))) bytes32Tobytes32ToBools;
    mapping(bytes32 => mapping(bytes32 => uint)) bytes32ToUints;
    mapping(bytes32 => mapping(address => bool)) address2Bools;

    mapping(bytes32 => UStruct[]) structArrays;

    function Database(address _mainAddr) public Module(_mainAddr) {}

    //Getters

    //Struct arrays

    function getUintFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(uint) {
        return structArrays[_arrayId][_structId].uints[_fieldId];
    }

    function getStringFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(string) {
        return structArrays[_arrayId][_structId].strings[_fieldId];
    }

    function getBoolFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(bool) {
        return structArrays[_arrayId][_structId].bools[_fieldId];
    }

    function getAddressFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(address) {
        return structArrays[_arrayId][_structId].addresses[_fieldId];
    }

    function getBytesFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(bytes) {
        return structArrays[_arrayId][_structId].bytesList[_fieldId];
    }

    function getBytes32FromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId) public view returns(bytes32) {
        return structArrays[_arrayId][_structId].bytes32s[_fieldId];
    }

    function getAddress2UintFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId, address _key) public view returns(uint) {
        return structArrays[_arrayId][_structId].address2Uints[_fieldId][_key];
    }

    function getAddress2BoolFromStructArrays(bytes32 _arrayId, uint _structId, uint _fieldId, address _key) public view returns(bool) {
        return structArrays[_arrayId][_structId].address2Bools[_fieldId][_key];
    }

    //Setters

    //Primitives

    function setUint(string _modName, bytes32 _id, uint _newVal) public onlyMod(_modName) {
        uints[_id] = _newVal;
    }

    function setString(string _modName, bytes32 _id, string _newVal) public onlyMod(_modName) {
        strings[_id] = _newVal;
    }

    function setBool(string _modName, bytes32 _id, bool _newVal) public onlyMod(_modName) {
        bools[_id] = _newVal;
    }

    function setAddress(string _modName, bytes32 _id, address _newVal) public onlyMod(_modName) {
        addresses[_id] = _newVal;
    }

    function setBytes(string _modName, bytes32 _id, bytes _newVal) public onlyMod(_modName) {
        bytesList[_id] = _newVal;
    }

    function setBytes32(string _modName, bytes32 _id, bytes32 _newVal) public onlyMod(_modName) {
        bytes32s[_id] = _newVal;
    }

    function setUint2Uint(string _modName, bytes32 _id, uint _key, uint _newVal) public onlyMod(_modName) {
        uint2Uints[_id][_key] = _newVal;
    }

    function setAddress2Uint(string _modName, bytes32 _id, address _key, uint _newVal) public onlyMod(_modName) {
        address2Uints[_id][_key] = _newVal;
    }

    function setBytes32ToBytes32ToBool(string _modName, bytes32 _id, bytes32 _key1, bytes32 _key2, bool _newVal) public onlyMod(_modName) {
        bytes32Tobytes32ToBools[_id][_key1][_key2] = _newVal;
    }

    function setBytes32ToUint(string _modName, bytes32 _id, bytes32 _key, uint _newVal) public onlyMod(_modName) {
        bytes32ToUints[_id][_key] = _newVal;
    }

    function setAddress2Bools(string _modName, bytes32 _id, address _key, bool _newVal) public onlyMod(_modName) {
        address2Bools[_id][_key] = _newVal;
    }

    //Struct arrays

    function setUintFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, uint _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].uints[_fieldId] = _newVal;
    }

    function setStringFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, string _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].strings[_fieldId] = _newVal;
    }

    function setBoolFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, bool _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].bools[_fieldId] = _newVal;
    }

    function setAddressFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, address _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].addresses[_fieldId] = _newVal;
    }

    function setBytesFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, bytes _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].bytesList[_fieldId] = _newVal;
    }

    function setBytes32FromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, bytes32 _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].bytes32s[_fieldId] = _newVal;
    }

    function setAddress2UintFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, address _key, uint _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].address2Uints[_fieldId][_key] = _newVal;
    }

    function setAddress2BoolFromStructArrays(string _modName, bytes32 _arrayId, uint _structId, uint _fieldId, address _key, bool _newVal) public onlyMod(_modName) {
        structArrays[_arrayId][_structId].address2Bools[_fieldId][_key] = _newVal;
    }
}
