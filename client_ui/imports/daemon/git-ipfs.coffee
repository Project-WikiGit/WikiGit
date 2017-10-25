###
  git-ipfs.coffee
  Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

  This file implements a daemon that listens for the TaskSolutionAccepted() event
  from the GitHandler module. Upon such an event, the daemon would clone the
  DASP's Git repo, pull from the updated repo where the task has been completed
  to merge the solution into the DASP's repo, publish the resulting repo onto IPFS,
  and send its IPFS multihash back to GitHandler as the current location of the DASP's repo.
###

import {DASP_Address} from '../ui/dasp_dashboard.js'

#Import web3
Web3 = require 'web3'
web3 = new Web3();
if web3.currentProvider == null
  web3.setProvider(new Web3.providers.HttpProvider("http://localhost:8545"))

#Import node modules
ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('ipfs.infura.io', '5001', {protocol: 'https'})
git = require 'gift'
fs = require 'fs'
keccak256 = require('js-sha3').keccak256

#Helper functions
hexToStr = (hex) ->
  hex = hex.substr(2)
  str = ''
  for i in [0..hex.length - 1] by 2
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
  return str

#Initialize main contract
mainAddr = DASP_Address.get()
mainAbi = require '../abi/mainABI.json'
mainContract = new web3.eth.Contract(mainAbi, mainAddr)

tasksHandlerAddr = tasksHandlerAbi = tasksHandlerContract = null
gitHandlerAddr = gitHandlerAbi = gitHandlerContract = null

#Get TasksHandler address
mainContract.methods.moduleAddresses('0x' + keccak256('TASKS')).call().then(
  (result) ->
    #Initialize TaskHandler module
    tasksHandlerAddr = result
    return main.methods.getABIHashForMod('0x' + keccak256('TASKS')).call().then(
      (abiHash) ->
        return new Promise((fullfill, reject) ->
          ipfs.files.cat(hexToStr(abiHash),
            (error, stream) ->
              if error != null
                reject(error)
              stream.pipe(bl((error, data) ->
                if error != null
                  reject(error)
                abi = JSON.parse(data.toString()).abi
                tasksHandlerContract = new web3.eth.Contract(abi, tasksHandlerAddr)
                fullfill()
                return
              ))
              return
          )
        )
    )
).then(
  () ->
    #Get GitHandler address
    mainContract.methods.moduleAddresses('0x' + keccak256('GIT')).call().then(
      (result) ->
        #Initialize GitHandler module
        gitHandlerAddr = result
        return main.methods.getABIHashForMod('0x' + keccak256('GIT')).call().then(
          (abiHash) ->
            return new Promise((fullfill, reject) ->
              ipfs.files.cat(hexToStr(abiHash),
                (error, stream) ->
                  if error != null
                    reject(error)
                  stream.pipe(bl((error, data) ->
                    if error != null
                      reject(error)
                    abi = JSON.parse(data.toString()).abi
                    gitHandlerContract = new web3.eth.Contract(abi, gitHandlerAddr)
                    fullfill()
                    return
                  ))
                  return
              )
            )
        )
    ).then(
      () ->
        #Listen for solution accepted event
        solutionAcceptedEvent = tasksHandlerContract.events.TaskSolutionAccepted()
        return solutionAcceptedEvent.on('data', (event) ->
          patchIPFSHash = hexToStr event.returnValues.patchIPFSHash
          gitHandlerContract.methods.getCurrentIPFSHash().call().then(
            (result) ->
              masterIPFSHash = hexToStr result
              masterPath = "./tmp/#{masterIPFSHash}/"

              #Create repo directory if it doesn't exist
              if !fs.existsSync(masterPath)
                if !fs.existsSync('./tmp')
                  fs.mkdirSync('./tmp')
                fs.mkdirSync(masterPath)

              #Clone the master
              git.clone("git@gateway.ipfs.io/ipfs/" + masterIPFSHash.toString(), masterPath, Number.POSITIVE_INFINITY, "master", (error, _repo) ->
                if error != null
                  throw error
                repo = _repo
                #Add patched repo as remote
                repo.remote_add("solution", "gateway.ipfs.io/ipfs/#{patchIPFSHash}", (error) ->
                  if error != null
                    throw error
                  #Pull the patched repo and merge with the master
                  repo.pull("solution", "master", (error) ->
                    if error != null
                      throw error
                    #Add new repo to the IPFS network
                    ipfs.util.addFromFs(masterPath, {recursive: true}, (error, result) ->
                      if error != null
                        throw error
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
)
