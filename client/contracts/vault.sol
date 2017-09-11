pragma solidity ^0.4.11;

import './main.sol';

import './erc20.sol';

contract Vault is Module {
    /*
        Defines how the vault will behave when a donor donates some ether.
        For each donation, the vault will grant multiplier * donationInWei / inputCurrencyPriceInWei
        tokens hosted at tokenAddress.
    */
    struct PayBehavior {
        /*
            Number of tokens that would be granted to donor for each input currency unit.
        */
        uint multiplier;

        /*
            Address of an oracle that returns the price of the desired input currency,
            such as USD, in Weis.
            Use zero if Wei is the desired input currency unit.
        */
        address oracleAddress;

        /*
            Address of the contract that grants donor tokens.
        */
        address tokenAddress;

        /*
            The pay behavior will only be valid if the current block number is
            larger than or equal to startBlockNumber.
        */
        uint startBlockNumber;

        /*
            The pay behavior will only be valid if the current block number is
            less than untilBlockNumber.
        */
        uint endBlockNumber;
    }

    struct PendingWithdrawl {
        uint amountInWeis;
        address to;
        uint frozenUntilBlock;
        bool isInvalid;
    }

    struct PendingTokenWithdrawl {
        uint amount;
        address to;
        uint frozenUntilBlock;
        bool isInvalid;
        string tokenSymbol; //Doesn't serve any use apart from enhancing readability.
        address tokenAddress;
    }

    PayBehavior[] public payBehaviors; //Array of pay behaviors.
    PendingWithdrawl[] public pendingWithdrawls;
    PendingTokenWithdrawl[] public pendingTokenWithdrawls;

    uint public withdrawlFreezeTime;
    uint public rewardFreezeTime;

    uint public frozenFunds;
    mapping(address => uint) public frozenTokens;

    function Vault(address mainAddr) Module(mainAddr) {
        //Initialize withdrawl freeze times
        rewardFreezeTime = 3524; //Roughly 24 hours
        withdrawlFreezeTime = 147; //Roughly 1 hour
    }

    //Import and export functions for updating modules.

    //Called by the old vault to transfer data to the new vault.
    function importFromVault(uint length) onlyMod('VAULT') {
        Vault oldVault = Vault(moduleAddress('VAULT'));
        for (uint i = 0; i < length; i++) {
            var (multiplier, oracleAddress, tokenAddress, startBlockNumber, endBlockNumber) = oldVault.payBehaviors(i);
            payBehaviors[i] = PayBehavior({
                multiplier: multiplier,
                oracleAddress: oracleAddress,
                tokenAddress: tokenAddress,
                startBlockNumber: startBlockNumber,
                endBlockNumber: endBlockNumber
            });
        }
    }

    //Transfers all data and funds to the new vault.
    function exportToVault(address newVaultAddr, bool burn) onlyMod('DAO') {
        Vault newVault = Vault(newVaultAddr);
        newVault.importFromVault(payBehaviors.length);
        if (burn) {
            selfdestruct(newVaultAddr);
        } else {
            newVault.transfer(this.balance);
        }
    }

    //Withdrawl handlers

    function addPendingWithdrawl(uint amountInWeis, address to, bool isReward) onlyMod('DAO') {
        uint availableFunds = this.balance - frozenFunds;
        require(availableFunds >= amountInWeis); //Make sure there's enough unfrozen Ether in the vault
        require(to.balance + amountInWeis > to.balance); //Prevent overflow

        frozenFunds += amountInWeis;

        uint blocksUntilWithdrawl;
        if (isReward) {
            blocksUntilWithdrawl = rewardFreezeTime;
        } else {
            blocksUntilWithdrawl = withdrawlFreezeTime;
        }

        pendingWithdrawls.push(PendingWithdrawl({
            amountInWeis: amountInWeis,
            to: to,
            frozenUntilBlock: block.number + blocksUntilWithdrawl,
            isInvalid: false
        }));
    }

    function addPendingTokenWithdrawl(
        uint amount,
        address to,
        string symbol,
        address tokenAddr,
        bool isReward
    )
        onlyMod('DAO')
    {
        ERC20 token = ERC20(tokenAddr);
        uint availableTokens = token.balanceOf(this) - frozenTokens[tokenAddr];
        require(availableTokens >= amount); //Make sure there's enough unfrozen tokens in the vault
        require(token.balanceOf(to) + amount > token.balanceOf(to)); //Prevent overflow

        frozenTokens[tokenAddr] += amount;

        uint blocksUntilWithdrawl;
        if (isReward) {
            blocksUntilWithdrawl = rewardFreezeTime;
        } else {
            blocksUntilWithdrawl = withdrawlFreezeTime;
        }

        pendingTokenWithdrawls.push(PendingTokenWithdrawl({
            amount: amount,
            to: to,
            frozenUntilBlock: block.number + blocksUntilWithdrawl,
            tokenSymbol: symbol,
            tokenAddress: tokenAddr,
            isInvalid: false
        }));
    }

    function payoutPendingWithdrawl(uint id) {
        require(id < pendingWithdrawls.length);
        PendingWithdrawl storage w = pendingWithdrawls[id];
        require(!w.isInvalid);
        require(block.number >= w.frozenUntilBlock);

        w.isInvalid = true;
        frozenFunds -= w.amountInWeis;

        w.to.transfer(w.amountInWeis);
    }

    function payoutPendingTokenWithdrawl(uint id) {
        require(id < pendingTokenWithdrawls.length);
        PendingTokenWithdrawl storage w = pendingTokenWithdrawls[id];
        require(!w.isInvalid);
        require(block.number >= w.frozenUntilBlock);

        w.isInvalid = true;
        frozenTokens[w.tokenAddress] -= w.amount;

        ERC20 token = ERC20(w.tokenAddress);
        token.transfer(w.to, w.amount);
    }

    function invalidatePendingWithdrawl(uint id) onlyMod('DAO') {
        require(id < pendingWithdrawls.length);
        PendingWithdrawl storage w = pendingWithdrawls[id];
        w.isInvalid = true;
        frozenFunds -= w.amountInWeis;
    }

    function invalidatePendingTokenWithdrawl(uint id) onlyMod('DAO') {
        require(id < pendingTokenWithdrawls.length);
        PendingTokenWithdrawl storage w = pendingTokenWithdrawls[id];
        w.isInvalid = true;
        frozenTokens[w.tokenAddress] -= w.amount;
    }

    function changeFreezeTime(uint newTime, bool isReward) onlyMod('DAO') {
        if (isReward) {
            rewardFreezeTime = newTime;
        } else {
            withdrawlFreezeTime = newTime;
        }
    }

    //Pay behavior manipulators.

    function addPayBehavior(
        uint multiplier,
        address oracleAddress,
        address tokenAddress,
        uint startBlockNumber,
        uint endBlockNumber
    )
        onlyMod('DAO')
    {
        payBehaviors.push(PayBehavior({
            multiplier: multiplier,
            oracleAddress: oracleAddress,
            tokenAddress: tokenAddress,
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber
        }));
    }

    function removePayBehaviorAtIndex(uint index) onlyMod('DAO') {
        delete payBehaviors[index];
    }

    function removeAllPayBehaviors() onlyMod('DAO') {
        delete payBehaviors;
    }

    //Handles incoming donation.
    function() payable {
        for (uint i = 0; i < payBehaviors.length; i++) {
            PayBehavior storage behavior = payBehaviors[i];
            if (behavior.startBlockNumber < block.number && block.number < behavior.endBlockNumber) {
                //Todo: implement specific interface for oracle and token
                if (behavior.oracleAddress == 0) {
                    ERC20 token = ERC20(behavior.tokenAddress);
                    token.transfer(msg.sender, behavior.multiplier * msg.value);
                } else {
                    /*
                    Oracle oracle = Oracle(behavior.oracleAddress);
                    uint inputCurrencyPriceInWeis = oracle.getPrice();
                    ERC20 token = ERC20(behavior.tokenAddress());
                    token.transfer(msg.sender, behavior.multiplier * msg.value / inputCurrencyPriceInWeis);
                    */
                }
            }
        }
    }
}
