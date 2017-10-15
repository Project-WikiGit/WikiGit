Web3 = require 'web3'
keccak256 = require('js-sha3').keccak256

web3 = new Web3();
web3.setProvider(new Web3.providers.HttpProvider("http://localhost:8545"))

ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})

git = require 'gift'

mainAddr = "0x90d82b1cf27933c7c9d046210f6d78691419c62d"
mainAbi = require './abi/mainABI.json'
mainContract = new web3.eth.Contract(mainAbi, mainAddr)

hexToStr = (hex) =>
  hex = hex.substr(2)
  str = ''
  for i in [0..hex.length-1] by 2
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
  return str

mainContract.methods.moduleAddresses('0x' + keccak256('TASKS')).call().then(
  (result) =>
    tasksHandlerAddr = result
    tasksHandlerAbi = require './abi/tasksHandlerABI.json'
    tasksHandlerContract = new web3.eth.Contract(tasksHandlerAbi, tasksHandlerAddr)

    mainContract.methods.moduleAddresses('0x' + keccak256('GIT')).call().then(
      (result) =>
        gitHandlerAddr = result
        gitHandlerAbi = require './abi/gitHandlerABI.json'
        gitHandlerContract = new web3.eth.Contract(gitHandlerAbi, gitHandlerAddr)

        solutionAcceptedEvent = tasksHandlerContract.events.TaskSolutionAccepted()
        solutionAcceptedEvent.on('data', (event) =>
          patchIPFSHash = hexToStr event.returnValues.patchIPFSHash
          gitHandlerContract.methods.getCurrentIPFSHash().call().then(
            (result) =>
              masterIPFSHash = hexToStr result
              masterPath = "./tmp/#{masterIPFSHash}/"
              git.clone "git@gateway.ipfs.io/ipfs/" + masterIPFSHash.toString(), masterPath, Number.POSITIVE_INFINITY, "master", (erro, _repo) ->
                repo = _repo
                repo.remote_add("solution", "gateway.ipfs.io/ipfs/#{patchIPFSHash}", (err) =>
                  repo.pull("solution", "master", (er) =>
                    ipfs.util.addFromFs(masterPath, {recursive: true}, (e, result) =>
                      if error == null
                        for entry in result
                          if entry.path is masterIPFSHash
                            gitHandlerContract.methods.commitTaskSolutionToRepo(
                              event.returnValues.taskId,
                              event.returnValues.solId,
                              entry.hash
                            ).send()
                            break
                    )
                  )
                )
          )
    )
  )
)
