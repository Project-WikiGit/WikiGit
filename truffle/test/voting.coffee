Dao = artifacts.require 'Dao'
contract('Dao',
  (accounts) =>
    it('should initialize votingTypes',
      () =>
        Dao.deployed().then(
          (instance) =>
            return instance.init()
        )
    )
)