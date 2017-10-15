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
              #return instance.init()
          )
      )
  )