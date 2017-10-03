Web3 = require 'web3'
if typeof web3 is undefined
  web3 = new Web3(Web3.givenProvider || "http://localhost:8545")
console.log(Web3)

ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})

git = require 'gift'

mainAddr = ""
mainAbi = require './abi/mainABI.json'
mainContract = new web3.eth.contract(mainAbi, mainAddr)

tasksHandlerAddr = mainContract.methods.moduleAddresses(sha3('TASKS'))
tasksHandlerAbi = require './abi/tasksHandlerABI.json'
tasksHandlerContract = new web3.eth.contract(tasksHandlerAbi, tasksHandlerAddr)

gitHandlerAddr = mainContract.methods.moduleAddresses(sha3('GIT'))
gitHandlerAbi = require './abi/gitHandlerABI.json'
gitHandlerContract = new web3.eth.contract(gitHandlerAbi, gitHandlerAddr)

solutionAcceptedEvent = tasksHandlerContract.TaskSolutionAccepted()
solutionAcceptedEvent.watch((error, event) =>
  patchIPFSHash = event.returnValues.patchIPFSHash
  masterIPFSHash = gitHandlerContract.methods.getCurrentIPFSHash
  masterPath = "./tmp/#{masterIPFSHash}/"
  git.clone "git@gateway.ipfs.io/ipfs/" + masterIPFSHash.toString(), masterPath, Number.POSITIVE_INFINITY, "master", (erro, _repo) ->
    repo = _repo
    repo.remote_add("solution", "gateway.ipfs.io/ipfs/#{patchIPFSHash}", (err) =>
      repo.pull("solution", "master", (er) =>
        ipfs.util.addFromFs(masterPath, {recursive: true}, (e, result) =>
          newHash = entry.hash for entry in result when entry.path is masterIPFSHash
          gitHandlerContract.methods.commitTaskSolutionToRepo(
            event.returnValues.taskId,
            event.returnValues.solId,
            newHash
          )
        )
      )
    )
)