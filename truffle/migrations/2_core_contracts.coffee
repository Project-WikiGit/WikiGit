main = artifacts.require 'Main'
dao = artifacts.require 'Dao'
member_handler = artifacts.require 'MemberHandler'
vault = artifacts.require 'Vault'
tasks_handler = artifacts.require 'TasksHandler'
git_handler = artifacts.require 'GitHandler'

ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})

git = require 'gift'

fs = require 'fs'

module.exports = (deployer) =>
  deployer.deploy(main, 'Test Metadata').then(
    () =>
      repoPath = './tmp/init_repo'

      if !fs.existsSync(repoPath)
        if !fs.existsSync('./tmp')
          fs.mkdirSync('./tmp')
        fs.mkdirSync(repoPath)

      newHash = ''
      git.init repoPath, (err, _repo) ->
        repo = _repo
        ipfs.util.addFromFs(repoPath, {recursive: true}, (error, result) =>
          if error == null
            for entry in result
              if entry.path is 'repo'
                newHash = entry.hash
                break

            return deployer.deploy([
              [dao, main.address],
              [member_handler, 'Test Username', main.address],
              [vault, main.address],
              [tasks_handler, main.address],
              [git_handler, main.address, newHash]
            ]).then(
              () =>
                return main.deployed().then(
                  (instance) =>
                    return instance.initializeModuleAddresses([
                      dao.address,
                      member_handler.address,
                      vault.address,
                      tasks_handler.address,
                      git_handler.address,
                    ])
                )
            ).then(
              () =>
                return dao.deployed().then(
                  (instance) =>
                    return instance.init()
                )
            )
        )
  )
