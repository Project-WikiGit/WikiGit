## Technical Details

This document describes the details of the three components of WikiGit: the back end, the front end, and the developer tools. The back end is under [/dev/contracts/](/dev/contracts/), the front end is under [/client_ui/](/client_ui/), and the developer tools is under [/dev/](/dev/).

### The Back End

The back end includes a ***DAO*** with a fully fledged voting mechanism; a ***MemberHandler*** that acts as a member manifest, with different rights associated with each member group; a ***Vault*** that allows for the safe withdrawl of funds, as well as ***reactive token minting*** that can be used for things like ICOs and honorary tokens (such as the unicorn token issued to people who donated to the Ethereum project); a ***TasksHandler*** for publishing tasks and accepting solutions on the crowdsourcing platform; and a ***GitHandler*** for communicating with the Git repository hosted by IPFS and storing the address of the repository.

#### Modular Design

All of the core smart contracts mentioned above were designed as individual modules. This design allows for both updating the code down the road via contract swapping, and introducing new functionalities via adding lightweight modules in order to prevent frequent updates of the heavyweight core contracts. Even though the frequent intercontract communication of a modularized design entails costing more gas during normal usage than a single-contract infrastructure, the benefits of this design means that it's a lot more easier to maintain, update, and debug such systems, which makes large-scale, complex DASPs possible.

Also, the modularized design means that it is possible to swap out a core module for something that's compatible with any third-party app of your choosing. For instance, you can replace the TaskHandler module for a contract that publishes task listings onto a third-party platform.

#### The Main Contract

The main contract serves as an index for all of a DASP's modules. Modules can be added/removed through DAO votings. It is the only contract in the back end that cannot be upgraded, but it's simple enough that you won't need to.

#### DAO

The DAO module handles the voting mechanics of the DASP. Any member that has the right to do so can start voting sessions, vote on proposals, conclude voting sessions after the alotted time has passed, execute the proposal, and so on.

The votes that each member have are weighted sums of multiple values: the member's reputation (connected to how many tasks they've completed) and the amount of each relevant token they own.

The attributes of a voting session can be customized by creating voting types, where one can set properties such as the quorum, minimum proportion of support votes required, the member groups that can vote, the length of the voting session, and the weights for calculating each member's vote.

The execution of a voting works as follows: when creating a voting, you can specify a set of transaction bytecodes (via passing their hashes) and a module that will execute the bytecodes. After the voting has been passed, anyone can call the executeVoting() function to execute any one of the transaction bytecodes, provided that they have the bytecodes that correspond to the stored hashes (you can only execute one at a time because Solidity doesn't allow passing bytes[] as an argument). It's similar to the democracy contract at https://www.ethereum.org/dao .

#### MemberHandler

The MemberHandler module stores the information about members of the DASP, and about member groups with different rights in the DASP. It also implements basic member manipulation features, like adding, removing, and banning members.

Freelancers and shareholders can call the MemberHandler to add themselves to the DASP and enjoy the respective rights, such as submitting task solutions, cast votes, and creating votings.

#### Vault

The Vault module implements the safe withdrawl of funds through freezing pending withdrawals for a certain period of time. During this time, the DAO can use a voting session to veto a malicious withdrawl. The freeze period can be different for withdrawals initiated by the DAO and withdrawls initiated by task posters who want to reward the submitter of solutions they accepted, so that you can shorten the freeze period for DAO withdrawals if you choose to trust DAO votings (you should).

The Vault also implements ***reactive token minting***, which means that during set periods of time, the Vault can tell a token contract to mint a certain amount of tokens proportional to the amount of Ether someone donates to the Vault contract, and send them to that person's address. It can be used for initiating naive (I)COs *("I" is in parentheses because you can do these funding periods whenever and whatever number of times you want)*, (I)COs with different token prices during different periods, (I)COs with multiple types of tokens, and much more. The Vault also uses oracles to read the price of Ether, so that you can set rules like: if you give me USD$10 worth of Ether, I'll give you so-and-so amount of tokens. This allows you to bind your token's price with that of a fiat currency or another token rather than Ether.

#### TasksHandler

TasksHandler handles functions such as posting tasks, submitting task solutions, and accepting task solutions.

The life of a task is as follows: a member posts a task => interested members clone the repository => members complete the task => members upload the updated repository to IPFS => members submit the IPFS hash to the DASP => poster of the task accepts the best solution => reward can be withdrawn after the freeze period, the DASP's repository is updated

Completing tasks can not only provide financial rewards like Ether and tokens, but also provide good reputation. The amount of reputational reward you receive for completing a task is specified by the task's poster. On the flip side, all members also have a bad reputation attached to them. You receive bad reputation when you're penalized by the DASP for submitting malicious task solutions. Reputations are local to the DASP, but it's possible to build a platform for viewing an account's reputation among all DASPs. If a member behaves too maliciously in a DASP, it can ban the member through a voting session.

#### GitHandler

Due to the fact that it's infeasible to have an on-chain Git implementation, Git would have to be handled by the off-chain front end that interacts with the on-chain logic. However, the GitHandler module does serve important functions. Firstly, it communicates with the front end to in turn communicate with the Git repository. Secondly, and most importantly, the GitHandler stores the entire history of the Git repository's IPFS hash (for those of you unfamiliar with IPFS, the address of files and directories in IPFS are represented by their hashes) as a tree identical to the type of tree structure used in Git itself. A new IPFS hash that incorporates the most recent task solution would have a pointer that points to the current hash. If the reference to the current hash had been changed to that of a hash that's lower in the tree, a new branch would automatically be formed upon pushing a new hash. **This design ensures that any attack on the repository (e.g. pushing a new IPFS hash that points to a malicious repo) can be easily reverted by changing the reference to the hash of the last working repo.**



For more information about the back end, just check out the code! All of the contracts were written with readability in mind and have been well commented, so it'd be a treat for those who prefer code to English.

### The Front End

The front end is a client-side web app that will be hosted on the IPFS network. It will include a registry where users can discover projects, as well as the UI needed to interact with DASPs.

The front end is based on Meteor and Node.js. It uses web3.js to communicate with a DASP's back end, and gift (a wrapper for the Git CLI) & js-ipfs-api to communicate with the DASP's Git repository on IPFS. 

The front end includes a daemon, which uses all of the Node.js modules mentioned above to connect a DASP with its Git repo. It works like this: the daemon listens for the TaskSolutionAccepted() event from the GitHandler module in the back end. Upon such an event, the daemon would clone the DASP's Git repo, pull from the updated repo where the task has been completed to merge the solution into the DASP's repo, publish the resulting repo onto IPFS, and send its IPFS multihash back to GitHandler as the current location of the DASP's repo. The ideal process would be where a solution's submitter can only upload a Git patch instead of the entire repo, but due to the limitations of the gift module, this currently cannot be implemented.

### Developer Tools

The developer tools is used for deploying DASPs onto the Ethereum blockchain. It is based on Truffle and node.js. Currently, it can only be used via command line, but an UI will be built in the near future.