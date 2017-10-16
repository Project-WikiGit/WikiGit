Dao = artifacts.require 'Dao'

contract('Dao',
  (accounts) =>
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
)