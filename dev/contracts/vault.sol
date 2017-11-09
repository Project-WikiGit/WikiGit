/*
    vault.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the DAP's vault, or in other words the manager
    of the DAP's funds. It allows for the delayed withdrawl of ethers
    and/or ERC20 tokens (the delay prevents malicious withdrawls), and
    giving people who donate ethers to the vault custom tokens in return.
    The latter function can be used to implement things like ICOs and
    honorary tokens (such as the unicorn token), and more.
*/

pragma solidity ^0.4.18;

import './main.sol';

import './erc20.sol';

contract Vault is Module {
    /*
        Defines how the vault will behave when a donor donates some ether.
        For each donation, the vault will grant multiplier * donationInWei / inputCurrencyPriceInWei
        tokens hosted at tokenAddress.
        The use of oracles is not yet implemented.
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
            Use of oracles not yet implemented.
        */
        //address oracleAddress;

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

        /*
            Implements a cap for the total amount of donation.
        */
        uint totalDonationInWeis;
        uint donationCapInWeis;
    }

    /*
        Defines a pending withdrawl of ether. Each withdrawl of funds is frozen for
        a period of time, when members scrutinize the validity of this withdrawl.
        If the pending withdrawl doesn't get invalidated by a voting, the payout function
        may be called by anyone to actualize the withdrawl.
    */
    struct PendingWithdrawl {
        /*
            The amount of the withdrawl, in weis.
        */
        uint amountInWeis;

        /*
            Address of the receipient.
        */
        address to;

        /*
            The block number until which the actual withdrawl of funds cannot be made.
        */
        uint frozenUntilBlock;

        /*
            Indicates whether this withdrawl is invalid.
        */
        bool isInvalid;
    }

    /*
        Defines a pending withdrawl of ERC20 tokens. Similar to PendingWithdrawl.
    */
    struct PendingTokenWithdrawl {
        /*
            The amount of the withdrawl.
        */
        uint amount;

        /*
            Address of the receipient.
        */
        address to;

        /*
            The block number until which the actual withdrawl of funds cannot be made.
        */
        uint frozenUntilBlock;

        /*
            Indicates whether this withdrawl is invalid.
        */
        bool isInvalid;

        /*
            The symbol of the token. Doesn't serve any use apart from enhancing readability.
        */
        string tokenSymbol;

        /*
            The address of the ERC20 token contract.
        */
        address tokenAddress;
    }

    PayBehavior[] public payBehaviorList; //List of pay behaviors.
    PendingWithdrawl[] public pendingWithdrawlList; // List of pending withdrawls.
    PendingTokenWithdrawl[] public pendingTokenWithdrawlList; //List of pending token withdrawls.

    uint public withdrawlFreezeTime; //The time for which a withdrawl requested by a DAO voting is frozen, in blocks.
    uint public rewardFreezeTime; //The time for which a withdrawl requested by a member rewarding someone who completed a task, in blocks.

    uint public frozenFunds; //The amount of ethers currently frozen, in weis.
    mapping(address => uint) public frozenTokens; //The amount of ERC20 tokens currently frozen. Mapping from token address to amount.

    function Vault(address mainAddr) Module(mainAddr) public {
        //Initialize withdrawl freeze times
        rewardFreezeTime = 3524; //Roughly 24 hours
        withdrawlFreezeTime = 3524; //Roughly 24 hours
    }

    //Import and export functions for updating modules.
    /*
    //Called by the old vault to transfer data to the new vault.
    function importFromVault(uint length) onlyMod('VAULT') {
        Vault oldVault = Vault(moduleAddress('VAULT'));
        for (uint i = 0; i < length; i++) {
            var (multiplier, oracleAddress, tokenAddress, startBlockNumber, endBlockNumber, _, donationCapInWeis)
                = oldVault.payBehaviorList(i);
            payBehaviorList[i] = PayBehavior({
                multiplier: multiplier,
                oracleAddress: oracleAddress,
                tokenAddress: tokenAddress,
                startBlockNumber: startBlockNumber,
                endBlockNumber: endBlockNumber,
                totalDonationInWeis: 0,
                donationCapInWeis: donationCapInWeis
            });
        }
    }

    //Transfers all data and funds to the new vault.
    function exportToVault(address newVaultAddr, bool burn) onlyMod('DAO') {
        Vault newVault = Vault(newVaultAddr);
        newVault.importFromVault(payBehaviorList.length);
        if (burn) {
            selfdestruct(newVaultAddr);
        } else {
            newVault.transfer(this.balance);
        }
    }
    */
    //Withdrawl handlers

    function addPendingWithdrawl(
        uint amountInWeis,
        address to,
        bool isReward
    )
        public
        onlyMod('DAO')
    {
        uint availableFunds = this.balance - frozenFunds;
        require(availableFunds >= amountInWeis); //Make sure there's enough free ether in the vault
        require(to.balance + amountInWeis > to.balance); //Prevent overflow

        frozenFunds += amountInWeis; //Freeze the pending withdrawl's amount.

        uint blocksUntilWithdrawl;
        if (isReward) {
            blocksUntilWithdrawl = rewardFreezeTime;
        } else {
            blocksUntilWithdrawl = withdrawlFreezeTime;
        }

        pendingWithdrawlList.push(PendingWithdrawl({
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
        public
        onlyMod('DAO')
    {
        ERC20 token = ERC20(tokenAddr);
        uint availableTokens = token.balanceOf(this) - frozenTokens[tokenAddr];
        require(availableTokens >= amount); //Make sure there's enough unfrozen tokens in the vault
        require(token.balanceOf(to) + amount > token.balanceOf(to)); //Prevent overflow

        frozenTokens[tokenAddr] += amount; //Freezes the pending withdrawl's amount.

        uint blocksUntilWithdrawl;
        if (isReward) {
            blocksUntilWithdrawl = rewardFreezeTime;
        } else {
            blocksUntilWithdrawl = withdrawlFreezeTime;
        }

        pendingTokenWithdrawlList.push(PendingTokenWithdrawl({
            amount: amount,
            to: to,
            frozenUntilBlock: block.number + blocksUntilWithdrawl,
            tokenSymbol: symbol,
            tokenAddress: tokenAddr,
            isInvalid: false
        }));
    }

    function payoutPendingWithdrawl(uint id) public {
        require(id < pendingWithdrawlList.length); //Ensure the id is valid.
        PendingWithdrawl storage w = pendingWithdrawlList[id];
        require(!w.isInvalid); //Ensure the withdrawl is valid.
        require(block.number >= w.frozenUntilBlock); //Ensure the vetting period has ended.

        w.isInvalid = true;
        frozenFunds -= w.amountInWeis; //Defrost the frozen funds for payout.

        w.to.transfer(w.amountInWeis);
    }

    function payoutPendingTokenWithdrawl(uint id) public {
        require(id < pendingTokenWithdrawlList.length); //Ensure the id is valid.
        PendingTokenWithdrawl storage w = pendingTokenWithdrawlList[id];
        require(!w.isInvalid); //Ensure the withdrawl is valid.
        require(block.number >= w.frozenUntilBlock); //Ensure the vetting period has ended.

        w.isInvalid = true;
        frozenTokens[w.tokenAddress] -= w.amount; //Defrost the frozen funds for payout.

        ERC20 token = ERC20(w.tokenAddress);
        token.transfer(w.to, w.amount);
    }

    function invalidatePendingWithdrawl(uint id) public onlyMod('DAO') {
        require(id < pendingWithdrawlList.length);
        PendingWithdrawl storage w = pendingWithdrawlList[id];
        w.isInvalid = true;
        frozenFunds -= w.amountInWeis; //Defrost the frozen funds.
    }

    function invalidatePendingTokenWithdrawl(uint id) public onlyMod('DAO') {
        require(id < pendingTokenWithdrawlList.length);
        PendingTokenWithdrawl storage w = pendingTokenWithdrawlList[id];
        w.isInvalid = true;
        frozenTokens[w.tokenAddress] -= w.amount; //Defrost the frozen funds.
    }

    function changeFreezeTime(uint newTime, bool isReward) public onlyMod('DAO') {
        if (isReward) {
            rewardFreezeTime = newTime;
        } else {
            withdrawlFreezeTime = newTime;
        }
    }

    //Pay behavior manipulators.

    function addPayBehavior(
        uint multiplier,
        //address oracleAddress,
        address tokenAddress,
        uint startBlockNumber,
        uint endBlockNumber,
        uint donationCapInWeis
    )
        public
        onlyMod('DAO')
    {
        payBehaviorList.push(PayBehavior({
            multiplier: multiplier,
            //oracleAddress: oracleAddress,
            tokenAddress: tokenAddress,
            startBlockNumber: startBlockNumber,
            endBlockNumber: endBlockNumber,
            totalDonationInWeis: 0,
            donationCapInWeis: donationCapInWeis
        }));
    }
    /*
    function removePayBehaviorAtIndex(uint index) onlyMod('DAO') {
        delete payBehaviorList[index];
    }

    function removeAllPayBehaviors() onlyMod('DAO') {
        delete payBehaviorList;
    }
    */
    //Handles incoming donation.
    function() public payable {
        for (uint i = 0; i < payBehaviorList.length; i++) {
            PayBehavior storage behavior = payBehaviorList[i];
            if (behavior.startBlockNumber < block.number && block.number < behavior.endBlockNumber) {
                //Todo: implement specific interface for oracle and token
                //if (behavior.oracleAddress == 0) {
                    //Ensure cap won't be exceeded
                    require(behavior.totalDonationInWeis + msg.value <= behavior.donationCapInWeis);
                    //Prevent overflow
                    require(behavior.totalDonationInWeis + msg.value >= behavior.totalDonationInWeis);

                    behavior.totalDonationInWeis += msg.value;

                    ERC20 token = ERC20(behavior.tokenAddress);
                    //Using transfer() here to conform with ERC20. Effectively mint().
                    //The token contract should have infinite tokens for the vault contract's account.
                    token.transfer(msg.sender, behavior.multiplier * msg.value);
                //} else {
                    /*
                    Oracle oracle = Oracle(behavior.oracleAddress);
                    uint inputCurrencyPriceInWeis = oracle.getPrice();
                    ERC20 token = ERC20(behavior.tokenAddress());
                    token.transfer(msg.sender, behavior.multiplier * msg.value / inputCurrencyPriceInWeis);
                    */
                //}
            }
        }
    }

    //Getters

    function getPayBehaviorListCount() public view returns(uint) {
        return payBehaviorList.length;
    }

    function getPendingWithdrawlListCount() public view returns(uint) {
        return pendingWithdrawlList.length;
    }

    function getPendingTokenWithdrawlListCount() public view returns(uint) {
        return pendingTokenWithdrawlList.length;
    }
}
