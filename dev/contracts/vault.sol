/*
    vault.sol
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file implements the DASP's vault, or in other words the manager
    of the DAP's funds. It allows for the delayed withdrawl of ethers
    and/or ERC20 tokens (the delay prevents malicious withdrawls), and
    giving people who donate ethers to the vault custom tokens in return.
    The latter function can be used to implement things like ICOs and
    honorary tokens (such as the unicorn token), and more.
*/

pragma solidity ^0.4.18;

import './token.sol';
import './main.sol';

contract Vault is Module {
    /*
        Defines how the vault will behave when a donor donates some ether.
        For each donation, the vault will grant multiplier * donationInWei / inputCurrencyPriceInWei
        tokens hosted at tokenAddress.
        The use of oracles is not yet implemented.
    */
    struct CoinOffering {
        /*
            Number of tokens that would be granted to donor for each input currency unit. Decimal.
        */
        uint multiplier;

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
            Implements a cap for the total amount of raised funds.
        */
        uint raisedFundsInWeis;
        uint hardCapInWeis;
    }

    /*
        Defines a pending withdrawl of ether. Each withdrawl of funds is frozen for
        a period of time, when members scrutinize the validity of this withdrawl.
        If the pending withdrawl doesn't get invalidated by a voting, the payout function
        may be called by anyone to actualize the withdrawl.
    */
    struct PendingWithdrawl {
        /*
            The amount of the withdrawl, in weis if it's an Ether withdrawl.
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

        bool isEther;

        /*
            Indicates whether this withdrawl is invalid.
        */
        bool isInvalid;
    }

    CoinOffering public currentCoinOffering;
    PendingWithdrawl[] public pendingWithdrawlList; // List of pending withdrawls.

    uint public withdrawlFreezeTime; //The time for which a withdrawl requested by a DAO voting is frozen, in blocks.
    uint public rewardFreezeTime; //The time for which a withdrawl requested by a member rewarding someone who completed a task, in blocks.

    uint public frozenFunds; //The amount of ethers currently frozen, in weis.
    uint public frozenTokens; //The amount of tokens currently frozen.

    function Vault(
        address _mainAddr,
        uint _rewardFreezeTime,
        uint _withdrawlFreezeTime
    )
        Module(_mainAddr)
        public
    {
        //Initialize withdrawl freeze times
        rewardFreezeTime = _rewardFreezeTime;
        withdrawlFreezeTime = _withdrawlFreezeTime;
    }

    //Withdrawl handlers

    function addPendingWithdrawl(
        uint _amount,
        address _to,
        bool _isReward,
        bool _isEther
    )
        public
        onlyMod('DAO')
    {
        uint blocksUntilWithdrawl;
        if (_isReward) {
            blocksUntilWithdrawl = rewardFreezeTime;
        } else {
            blocksUntilWithdrawl = withdrawlFreezeTime;
        }

        //Check if vault has enough funds for the withdrawl
        //If so, freeze the fund that will be withdrawn
        if (_isEther) {
            uint availableFunds = this.balance - frozenFunds;
            require(availableFunds >= _amount); //Make sure there's enough free ether in the vault
            require(_to.balance + _amount > _to.balance); //Prevent overflow

            frozenFunds += _amount; //Freeze the pending withdrawl's amount.
        } else {
            Token token = Token(moduleAddress('TOKEN'));
            uint availableTokens = token.balanceOf(address(this)) - frozenTokens;
            require(availableTokens >= _amount); //Make sure there's enough unfrozen tokens in the vault
            require(token.balanceOf(_to) + _amount > token.balanceOf(_to)); //Prevent overflow

            frozenTokens += _amount; //Freezes the pending withdrawl's amount.
        }

        pendingWithdrawlList.push(PendingWithdrawl({
            amount: _amount,
            to: _to,
            frozenUntilBlock: block.number + blocksUntilWithdrawl,
            isEther: _isEther,
            isInvalid: false
        }));
    }

    function payoutPendingWithdrawl(uint _id) public {
        require(_id < pendingWithdrawlList.length); //Ensure the id is valid.
        PendingWithdrawl storage w = pendingWithdrawlList[_id];
        require(!w.isInvalid); //Ensure the withdrawl is valid.
        require(block.number >= w.frozenUntilBlock); //Ensure the vetting period has ended.

        w.isInvalid = true;

        if (w.isEther) {
            frozenFunds -= w.amount; //Defrost the frozen funds for payout.
            w.to.transfer(w.amount);
        } else {
            frozenTokens -= w.amount; //Defrost the frozen funds for payout.
            Token token = Token(moduleAddress('TOKEN'));
            token.transfer(w.to, w.amount);
        }
    }

    function invalidatePendingWithdrawl(uint _id) public onlyMod('DAO') {
        require(_id < pendingWithdrawlList.length);
        PendingWithdrawl storage w = pendingWithdrawlList[_id];
        w.isInvalid = true;
        if (w.isEther) {
            frozenFunds -= w.amount; //Defrost the frozen funds.
        } else {
            frozenTokens -= w.amount; //Defrost the frozen funds.
        }
    }

    function changeFreezeTime(uint _newTime, bool _isReward) public onlyMod('DAO') {
        if (_isReward) {
            rewardFreezeTime = _newTime;
        } else {
            withdrawlFreezeTime = _newTime;
        }
    }

    //Coin offering manipulators.

    function startCoinOffering(
        uint _multiplier,
        address _tokenAddress,
        uint _startBlockNumber,
        uint _endBlockNumber,
        uint _donationCapInWeis
    )
        public
        onlyMod('DAO')
    {
        currentCoinOffering = CoinOffering({
            multiplier: _multiplier,
            tokenAddress: _tokenAddress,
            startBlockNumber: _startBlockNumber,
            endBlockNumber: _endBlockNumber,
            totalDonationInWeis: 0,
            donationCapInWeis: _donationCapInWeis
        });
    }

    //Handles incoming donation.
    function() public payable {
        if (currentCoinOffering.startBlockNumber < block.number && block.number < currentCoinOffering.endBlockNumber) {
            //Ensure cap won't be exceeded
            require(currentCoinOffering.raisedFundsInWeis + msg.value <= currentCoinOffering.hardCapInWeis);
            //Prevent overflow
            require(currentCoinOffering.raisedFundsInWeis + msg.value >= currentCoinOffering.raisedFundsInWeis);

            currentCoinOffering.raisedFundsInWeis += msg.value;

            Token token = Token(moduleAddress('TOKEN'));
            token.mint(msg.sender, currentCoinOffering.multiplier * msg.value / decimals);
        }
    }

    //Getters

    function getPendingWithdrawlListCount() public view returns(uint) {
        return pendingWithdrawlList.length;
    }
}
