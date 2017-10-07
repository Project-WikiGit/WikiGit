main = artifacts.require 'Main'
dao = artifacts.require 'Dao'
vault = artifacts.require 'Vault'
tasks_handler = artifacts.require 'TasksHandler'
git_handler = artifacts.require 'GitHandler'

module.exports = (deployer) =>
  deployer.deploy(main, 'Test Metadata').then(
    () =>
      return deployer.deploy([
        [dao, 'Zefram Lou', main.address],
        [vault, main.address],
        [tasks_handler, main.address],
        [git_handler, main.address]
      ])
  )