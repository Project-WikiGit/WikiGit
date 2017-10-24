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

export DASP = () ->
  self = this
  self.metadata = null

  self.addrs =
    main: null
    dao: null
    member: null
    vault: null
    tasks: null
    git: null

  self.contracts =
    main: null
    dao: null
    member: null
    vault: null
    tasks: null
    git: null

  self.repoIPFSHash = null

  self.initWithAddr = (addr, options, callback) ->
    self.addrs.main = addr
    mainAbi = (options && options.mainAbi) || require "../abi/mainABI.json"
    self.contracts.main = new web3.eth.Contract(mainAbi, self.addrs.main)
    moduleNames = (options && options.moduleNames) || ['DAO', 'MEMBER', 'VAULT', 'TASKS', 'GIT']
    initMod = (mod) ->
      return self.contracts.main.methods.moduleAddresses('0x' + keccak256(mod)).call().then(
        (result) ->
          lowerMod = mod.toLowerCase()
          self.addrs[lowerMod] = result;
          abi = (options && options.mainAbi) || require("../abi/daoABI.json")
          self.contracts[lowerMod] = new web3.eth.Contract(abi, self.addrs[lowerMod])
          return
      )
    initAllMods = (initMod(mod) for mod in moduleNames)
    Promise.all(initAllMods).then(
      ()->
        self.contracts.git.methods.getCurrentIPFSHash().call().then(
          (result) ->
            self.repoIPFSHash = hexToStr result
            if callback != null
              callback
            return
        )
    )

    return

  self.lsRepo = (path, callback) ->
    ipfs.ls("#{self.repoIPFSHash}#{path}", (error, result) ->
      console.log(error, result)
      if error
        callback(error, null)
      else
        callback(null, result.Objects[0].Links)
    )
    return

  return
