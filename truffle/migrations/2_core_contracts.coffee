main = require 'Main'
dao = require 'Dao'
vault = require 'Vault'
tasks_handler = require 'TasksHandler'
git_handler = require 'GitHandler'

module.exports = (deployer) =>
  deployer.deploy(main, 'Test Metadata').then(
    () =>
      return deployer.deploy(
        [dao, 'Zefram Lou', main.address],
        [vault, main.address],
        [tasks_handler, main.address],
        [git_handler, main.address]
      )
  )