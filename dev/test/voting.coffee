Dao = artifacts.require 'Dao'
MemberHandler = artifacts.require 'MemberHandler'
daoAddr = '0xbcfc50e23f9938a6376083dbb9392271dcca45af'
memAddr = '0x7b657f1a84693d70fea10d99a290c873fdbe5b5d'
contract('Dao',
  (accounts) ->
    account1 = accounts[0];
    account2 = accounts[1];
    it('create voting',
      () ->
        return Dao.at(daoAddr).then(
          (instance) ->
            return instance.createVoting(
              'Test Voting',
              'For testing the creation of votings',
              0,
              100,
              [],
              "0x0"
            )
        )
    )
    it('has right',
      () ->
        return MemberHandler.at(memAddr).then(
          (instance) ->
            return instance.memberHasRight(account1, 'vote')
        )
    )
    it('vote on voting',
      () ->
        return Dao.at(daoAddr).then(
          (instance) ->
            return instance.vote(
              5,
              true
            )
        )
    )
    return
)