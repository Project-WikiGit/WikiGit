###contract = require 'truffle-contract'
Web3 = require('web3')
provider = new Web3.providers.HttpProvider("http://localhost:8545")

main = contract(require '../build/contracts/Main.json')
dao = contract(require '../build/contracts/Dao.json')
member_handler = contract(require '../build/contracts/MemberHandler.json')
vault = contract(require '../build/contracts/Vault.json')
tasks_handler = contract(require '../build/contracts/TasksHandler.json')
git_handler = contract(require '../build/contracts/GitHandler.json')

main.provider = provider
dao.provider = provider
member_handler.provider = provider
vault.provider = provider
tasks_handler.provider = provider
git_handler.provider = provider###

main = artifacts.require 'Main'
dao = artifacts.require 'Dao'
member_handler = artifacts.require 'MemberHandler'
vault = artifacts.require 'Vault'
tasks_handler = artifacts.require 'TasksHandler'
git_handler = artifacts.require 'GitHandler'

module.exports = (deployer) =>
  deployer.deploy(main, 'Test Metadata').then(
    () =>
      return deployer.deploy([
        [dao, main.address],
        [member_handler, 'Test Username', main.address],
        [vault, main.address],
        [tasks_handler, main.address],
        [git_handler, main.address]
      ]).then(
        () =>
          return dao.deployed().then(
            (instance) =>
              return instance.init()
          )
      )
  )