Web3 = require 'web3'
keccak256 = require('js-sha3').keccak256

if web3 is undefined
  web3 = new Web3(Web3.providers.HttpProvider("http://localhost:8545"))
else
  web3 = new Web3(web3.currentProvider)

ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})

git = require 'gift'

mainAddr = "0xba8431cdf9508447b9655ed41a286b66abfedebd"
mainAbi = require './abi/mainABI.json'
mainContract = new web3.eth.Contract(mainAbi, mainAddr)

mainContract.methods.moduleAddresses(keccak256('TASKS')).call().then(
  (taskHandlerAddr) =>
    tasksHandlerAbi = require './abi/tasksHandlerABI.json'
    tasksHandlerContract = new web3.eth.Contract(tasksHandlerAbi, tasksHandlerAddr)

    mainContract.methods.moduleAddresses(keccak256('GIT')).call().then(
      (gitHandlerAddr) =>
        gitHandlerAbi = require './abi/gitHandlerABI.json'
        gitHandlerContract = new web3.eth.Contract(gitHandlerAbi, gitHandlerAddr)

        solutionAcceptedEvent = tasksHandlerContract.events.TaskSolutionAccepted()
        solutionAcceptedEvent.watch((error, event) =>
          patchIPFSHash = event.returnValues.patchIPFSHash
          gitHandlerContract.methods.getCurrentIPFSHash().call().then(
            (masterIPFSHash) =>
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
    )
  )
)
