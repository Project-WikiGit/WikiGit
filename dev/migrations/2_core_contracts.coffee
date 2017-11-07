###
  2_core_contracts.coffee
  Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

  This file defines the deployment process of the core contracts of
  the DASP. In addition, it initializes the DASP's Git repo,
  publishes it onto the IPFS network, and saves its hash in the
  GitHandler module.
###

#Initialize contract abstractions
main = artifacts.require 'Main'
dao = artifacts.require 'Dao'
member_handler = artifacts.require 'MemberHandler'
vault = artifacts.require 'Vault'
tasks_handler = artifacts.require 'TasksHandler'
git_handler = artifacts.require 'GitHandler'

#Import node modules
ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('ipfs.infura.io', '5001', {protocol: 'https'})
git = require 'gift'
fs = require 'fs'

module.exports = (deployer) ->
  abiPath = './build/contracts/'
  ipfs.util.addFromFs(abiPath, {recursive: true}, (error, abiFiles) ->
    if error != null
      throw error

    getABIHash = (modName) ->
      for f in abiFiles
        #js-ipfs-api bug in Windows
        if f.path == "D:WebstormProjects/WikiGit/dev/build/contracts/#{modName}.json"
          return f.hash

    mainHash = getABIHash('Main')
    #Deploy main contract
    deployer.deploy(main, 'Test Metadata', mainHash).then(
      () ->
        repoPath = './tmp/repo.git'

        #Create repo directory if it doesn't exist
        if !fs.existsSync(repoPath)
          if !fs.existsSync('./tmp')
            fs.mkdirSync('./tmp')
          fs.mkdirSync(repoPath)

        newHash = ''
        #Initialize Git repo
        git.init(repoPath, true, (error, _repo) ->
          if error != null
            throw error
          #Add repo to the IPFS network
          ipfs.util.addFromFs(repoPath, {recursive: true}, (error, result) ->
            if error != null
              throw error
            #Get repo's IPFS multihash
            newHash = result[result.length - 1].hash
            #Deploy core modules
            deployer.deploy([
              [dao, main.address],
              [member_handler, 'Test Username', main.address],
              [vault, main.address],
              [tasks_handler, main.address],
              [git_handler, newHash, main.address]
            ]).then(
              () ->
                #Add core module addresses to main contract
                return main.deployed().then(
                  (instance) ->
                    return instance.initializeModuleAddresses([
                      dao.address,
                      member_handler.address,
                      vault.address,
                      tasks_handler.address,
                      git_handler.address
                    ])
                )
            ).then(
              () ->
                #Initialize the DAO
                return dao.deployed().then(
                  (instance) ->
                    return instance.init()
                )
            ).then(
              () ->
                #Initialize the ABI hashes
                modAbsNames = ['Dao', 'MemberHandler', 'Vault', 'TasksHandler', 'GitHandler']
                return main.deployed().then(
                  (instance) ->
                    initABIHashForMod = (modId) ->
                      return instance.initializeABIHashForMod(modId, getABIHash(modAbsNames[modId]))
                    return Promise.all(initABIHashForMod(modId) for modId in [0..4])
                )
            )
          )
        )
    )
  )

