/**
 * 1_initial_migration.js
 * Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.
 *
 * This file deploys the initial migration contract required by Truffle.
 */

let truffle_migration = artifacts.require('Migrations');

module.exports = (deployer) => {
    deployer.deploy(truffle_migration);
};