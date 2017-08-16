pragma solidity ^0.4.11;

import './main.sol';

contract Vault {
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
            less than untilBlockNumber.
        */
        uint untilBlockNumber;
    }
    address public constant mainAddress; //Address of the main contract.
    PayBehavior[] public payBehaviors; //Array of pay behaviors.

    modifier onlyDao {
        Main mainContract = Main(mainAddress);
        require(msg.sender == mainContract.moduleAddresses['DAO']);
        _;
    }

    function Vault(address mainAddr){
        mainAddress = mainAddr;
    }

    function withdraw(uint amountInWeis, address toAddr) onlyDao {
        require(this.balance >= amountInWeis); //Make sure there's enough Ether in the vault
        require(toAddr.balance + amountInWeis > toAddr.balance); //Prevent overflow
        toAddr.transfer(amountInWeis);
    }

    //Pay behavior manipulators.

    function addPayBehavior(PayBehavior behavior) onlyDao {
        payBehaviors.push(behavior);
    }

    function removePaybehavior(PayBehavior behavior) onlyDao {
        for(uint i = 0; i < payBehaviors.length; i++) {
            if(behavior == payBehaviors[i]) {
                delete payBehaviors[i];
                break;
            }
        }
    }

    function removePayBehaviorAtIndex(uint index) onlyDao {
        delete payBehaviors[index];
    }

    function removeAllPayBehaviors() onlyDao {
        delete payBehaviors;
    }

    //Handles incoming donation.

    function () payable {
        for(uint i = 0; i < payBehaviors.length; i++) {
            PayBehavior behavior = payBehaviors[i];
            if (block.number < behavior.untilBlockNumber) {
                /*
                Oracle oracle = Oracle(behavior.oracleAddress);
                uint inputCurrencyPriceInWeis = oracle.getPrice();
                Token token = Token(behavior.tokenAddress());
                token.grant(behavior.multiplier * msg.value / inputCurrencyPriceInWeis);
                */
            }
        }
    }
}
