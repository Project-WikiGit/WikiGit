main = artifacts.require 'Main'
dao = artifacts.require 'Dao'
member_handler = artifacts.require 'MemberHandler'
vault = artifacts.require 'Vault'
tasks_handler = artifacts.require 'TasksHandler'
git_handler = artifacts.require 'GitHandler'

ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('localhost', '5001', {protocol: 'http'})

git = require 'gift'

module.exports = (deployer) =>
  deployer.deploy(main, 'Test Metadata').then(
    () =>
      repoPath = './tmp/repo' #Todo: create local directory
      newHash = ''
      git.init repoPath, true, (err, _repo) ->
        repo = _repo
        ipfs.util.addFromFs(repoPath, {recursive: true}, (error, result) =>
          if error == null
            for entry in result
              if entry.path is 'repo'
                newHash = entry.hash
                break
            decode = (dec) =>
              alphabet = '123456789abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
              base = alphabet.length
              decoded = 0;
              while(dec)
                alphabetPosition = alphabet.indexOf(dec[0])
                powerOf = dec.length - 1
                decoded += alphabetPosition * (Math.pow(base, powerOf))
                dec = dec.substring(1)
              return decoded

            return deployer.deploy([
              [dao, main.address],
              [member_handler, 'Test Username', main.address],
              [vault, main.address],
              [tasks_handler, main.address],
              [git_handler, main.address, newHash.slice(2), decode newHash.slice(0, 1), decode newHash.slice(1, 2)]
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
