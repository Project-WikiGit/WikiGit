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
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})
git = require 'gift'
fs = require 'fs'

module.exports = (deployer) ->
  #Deploy main contract
  deployer.deploy(main, 'Test Metadata').then(
    () ->
      repoPath = './tmp/init_repo'

      #Create repo directory if it doesn't exist
      if !fs.existsSync(repoPath)
        if !fs.existsSync('./tmp')
          fs.mkdirSync('./tmp')
        fs.mkdirSync(repoPath)

      newHash = ''
      #Initialize Git repo
      git.init(repoPath, (error, _repo) ->
        if error != null
          throw error
        #Add repo to the IPFS network
        ipfs.util.addFromFs(repoPath, {recursive: true}, (error, result) ->
          if error != null
            throw error
          #Get repo's IPFS multihash
          for entry in result
            if entry.path is 'repo'
              newHash = entry.hash
              break
          #Deploy core modules
          deployer.deploy([
            [dao, main.address],
            [member_handler, 'Test Username', main.address],
            [vault, main.address],
            [tasks_handler, main.address],
            [git_handler, main.address, newHash]
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
                  ],0) #added 0 due to Truffle bug
              )
          ).then(
            () ->
              #Initialize the DAO
              return dao.deployed().then(
                (instance) ->
                  return instance.init()
              )
          )
        )
      )
  )
