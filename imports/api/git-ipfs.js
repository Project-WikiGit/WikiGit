var web3 = new Web3(Web3.givenProvider || "ws://localhost:8546");
var ipfsAPI = require('ipfs-api')
var ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'});

var mainAddr = "";
var mainAbi = [{"constant":true,"inputs":[{"name":"","type":"bytes32"}],"name":"moduleAddresses","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"initialized","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"metadata","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"moduleNames","outputs":[{"name":"","type":"string"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"index","type":"uint256"}],"name":"removeModuleAtIndex","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"modName","type":"string"},{"name":"addr","type":"address"},{"name":"isNew","type":"bool"}],"name":"changeModuleAddress","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"addrs","type":"address[]"}],"name":"initializeModuleAddresses","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":false,"inputs":[{"name":"meta","type":"string"}],"name":"changeMetadata","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"inputs":[{"name":"meta","type":"string"}],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":false,"stateMutability":"nonpayable","type":"fallback"}];
var mainContract = new web3.eth.contract(mainAbi, mainAddr);

var taskHandlerAddr = mainContract.methods.moduleAddresses(sha3('TASKS'));
var taskHandlerAbi = []; //TBD
var taskHandlerContract = new web3.eth.contract(taskHandlerAbi, taskHandlerAddr);

var solutionAcceptedEvent = taskHandlerContract.TaskSolutionAccepted();
solutionAcceptedEvent.watch((error, event) => {
    var patchIPFSHash = event.returnValues.patchIPFSHash;
    //Retrieve patch data
    var patchData;
    ipfs.get(patchIPFSHash, (err, stream) => {
        stream.resume()
            .on('data', (chunk) => {
                patchData += chunk;
            })
            .on('end', () => {
                //Apply patch to repo

                //Post repo to IPFS

                //Update repo hash
            });
    });
});