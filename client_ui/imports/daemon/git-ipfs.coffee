###
  git-ipfs.coffee
  Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

  This file implements a daemon that listens for the TaskSolutionAccepted() event
  from the GitHandler module. Upon such an event, the daemon would clone the
  DASP's Git repo, pull from the updated repo where the task has been completed
  to merge the solution into the DASP's repo, publish the resulting repo onto IPFS,
  and send its IPFS multihash back to GitHandler as the current location of the DASP's repo.
###

import {dasp} from '../ui/dasp_dashboard.js'

#Import web3
Web3 = require 'web3'
web3 = window.web3
if typeof web3 != undefined
  web3 = new Web3(web3.currentProvider)
else
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"))

web3.eth.getAccounts().then(
  (accounts) ->
    web3.eth.defaultAccount = accounts[0]
)

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

export StartDaemon = () ->
  #Fetch contract abstractions
  tasksHandlerContract = dasp.contracts.tasks
  gitHandlerContract = dasp.contracts.git

  solutionAcceptedEvent = tasksHandlerContract.events.TaskSolutionAccepted()
  solutionAcceptedEvent.on('data', (event) ->
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
  return
