var truffle_migration = artifacts.require('Migrations');

module.exports = (deployer) => {
    deployer.deploy(truffle_migration);
};