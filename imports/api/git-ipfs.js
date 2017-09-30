var web3 = new Web3(Web3.givenProvider || "ws://localhost:8546");

var ipfsAPI = require('ipfs-api')
var ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'});

var modes = require('/../lib/js-git/lib/modes');
var repo = {};
require('/../lib/js-git/mixins/mem-db')(repo);

var mainAddr = "";
var mainAbi = require('./abi/mainABI.json');
var mainContract = new web3.eth.contract(mainAbi, mainAddr);

var tasksHandlerAddr = mainContract.methods.moduleAddresses(sha3('TASKS'));
var tasksHandlerAbi = require('./abi/tasksHandlerABI.json');
var tasksHandlerContract = new web3.eth.contract(tasksHandlerAbi, tasksHandlerAddr);

var gitHandlerAddr = mainContract.methods.moduleAddresses(sha3('GIT'));
var gitHandlerAbi = require('./abi/gitHandlerABI.json');
var gitHandlerContract = new web3.eth.contract(gitHandlerAbi, gitHandlerAddr);

var solutionAcceptedEvent = tasksHandlerContract.TaskSolutionAccepted();
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
                var repoIPFSHash = gitHandlerContract.methods.getCurrentIPFSHash();
                var repoData;
                ipfs.get(repoIPFSHash, (e, s) => {
                    s.resume()
                        .on('data', (c) => {
                            repoData += c;
                        })
                        .on('end', () => {
                            //Apply patch to repo
                            
                            //Post repo to IPFS
                            var rStream = new stream.Readable({
                                objectMode: true,
                                read: (size) => {
                                    this.push();
                                }
                            });
                            ipfs.add();
                            //Update repo hash
                        })
                })
            });
    });
});