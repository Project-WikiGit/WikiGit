Dao = artifacts.require 'Dao'

contract('Dao',
  (accounts) =>
    account1 = accounts[0];
    account2 = accounts[1];
    it('create voting',
      () =>
        Dao.deployed().then(
          (instance) =>
            return instance.createVoting(
              'Test Voting',
              'For testing the creation of votings',
              0,
              0,
              [],
              "0x0"
            )
        )
    )
    it('vote on voting',
      () =>
        Dao.deployed().then(
          (instance) =>
            return instance.vote(
              0,
              true
            )
        )
    )
)