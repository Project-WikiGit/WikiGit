## Technical Details

This document describes the details of the three components of WikiGit: the back end, the front end, and the developer tools. The back end is under [/dev/contracts/](/dev/contracts/), the front end is under [/client_ui/](/client_ui/), and the developer tools is under [/dev/](/dev/).

This document is for WikiGit version **0.2.0 (Grasshopper)**.

### The Back End

The back end includes a ***DAO*** with a fully fledged voting mechanism; a ***MemberHandler*** that acts as a member manifest, with different rights associated with each member group; a ***Vault*** that allows for the safe withdrawl of funds, as well as holding coin offerings; a ***TasksHandler*** for publishing tasks and accepting solutions on the crowdsourcing platform; and a ***RepoHandler*** for democratically determining the IPFS hash of the DASP's git repository.

#### Modular Design

All of the core smart contracts mentioned above were designed as individual modules. This design allows for both updating the code down the road via contract swapping, and introducing new functionalities via adding lightweight modules in order to prevent frequent updates of the heavyweight core contracts. Even though the frequent intercontract communication of a modularized design entails costing more gas during normal usage than a single-contract infrastructure, the benefits of this design means that it's a lot more easier to maintain, update, and debug such systems, which makes large-scale, complex DASPs possible.

Also, the modularized design means that it is possible to swap out a core module for something that's compatible with any third-party app of your choosing. For instance, you can replace the TaskHandler module for a contract that publishes task listings onto a third-party platform.

As of Grasshopper, upgrading a module without writing a specific migration script would result in the loss of all data stored in the module. We intend to address this issue later on.

#### The Main Contract

The main contract serves as an index for all of a DASP's modules. Modules can be added/removed through DAO votings. It is the only contract in the back end that cannot be upgraded, but it's simple enough that you won't need to.

#### DAO

The DAO module handles the voting mechanics of the DASP. Any member that has the right to do so can start voting sessions, vote on proposals, conclude voting sessions after the alotted time has passed, execute the proposal, and so on.

The votes that each member have are weighted sums of multiple values: the member's reputation (determined by how many tasks they've completed) and the amount of DASP specific token they own.

The attributes of a voting session are determined at DAO's creation, where one can set properties such as the quorum, minimum proportion of support votes required, the length of the voting session, and the weights involved in calculating each member's vote.

The execution of a voting works as follows: when creating a voting, you can specify a transaction bytecode (via passing in its hash) and an address that will receive the transaction. After the voting has been passed, anyone can call the executeVoting() function to execute the transaction bytecode, provided that they have the bytecode that correspond to the stored hash. It's similar to the democracy contract at https://www.ethereum.org/dao .

#### MemberHandler

The MemberHandler module stores the information about members of the DASP, and about member groups with different rights in the DASP. It also implements basic member manipulation features, like adding, removing, and banning members.

There are three groups of members: Team members, contributors, and pure shareholders.

* Team members are the core contributors to the project, with the right to vote, start voting sessions, post tasks with bounties, submit task solutions, vote on task solutions, and provide IPFS hashes to the DASP's repo.

* Contributors are people who contribute to the DASP part-time, with the right to vote, start voting sessions, post tasks without bounties, and submit task solutions.

* Pure shareholders are people who own DASP specific tokens issued during coin offerings, and do not contribute to the DASP, with the right to vote and start voting sessions.

In Grasshopper, the member groups and the associated rights can be modified, but this feature will not be included in the UI.

#### Vault

The Vault module implements the safe withdrawl of funds through freezing pending withdrawals for a certain period of time. During this time, the DAO can use a voting session to veto a malicious withdrawl. The freeze period can be different for withdrawals initiated by the DAO and withdrawls initiated by task posters who want to reward the submitter of solutions they accepted, so that you can shorten the freeze period for DAO withdrawals if you choose to trust DAO votings (you should).

The Vault also implements ***coin offerings***, which means that during set periods of time, the Vault can tell a token contract to mint a certain amount of tokens proportional to the amount of Ether someone donates to the Vault contract, and send them to that person's address.

#### TasksHandler

TasksHandler handles functions such as posting tasks, submitting task solutions, and accepting task solutions.

The life of a task is as follows: a member posts a task => interested members clone the repository => members complete the task => members upload the Git patch to IPFS => members submit the IPFS hash to the DASP => team members vote on solutions => A solution upvoted by more than 2/3 team members is accepted, while solutions downvoted by more than 2/3 team members are penalized => reward can be withdrawn by the winner after the freeze period => team members download patch, apply to repo, and upload to IPFS => team members update their version of the most up-to-date repo in RepoHandler, in the form of IPFS hashes => the IPFS hash with majority support is displayed as the repo's hash in the UI

Completing tasks can not only provide financial rewards like Ether and tokens, but also provide good reputation. The amount of reputational reward you receive for completing a task is specified by the task's poster. On the flip side, all members also have a bad reputation attached to them. You receive bad reputation when you're penalized by the DASP for submitting malicious task solutions. Reputations are local to the DASP, but it's possible to build a platform for viewing an account's reputation among all DASPs. If a member behaves too maliciously in a DASP, the DAO can ban the member through a voting session.

#### RepoHandler

The purpose of RepoHandler has been explained in the TasksHandler section.



For more information about the back end, just check out the code! All of the contracts were written with readability in mind and have been well commented, so it'd be a treat for those who prefer code to English.

### The Front End

The front end is a client-side web app that will be hosted on the IPFS network. It will include a registry where users can discover projects, as well as the UI needed to interact with DASPs.

The front end is based on Meteor and Node.js. It uses web3.js to communicate with a DASP's back end, and gift (a wrapper for the Git CLI) & js-ipfs-api to communicate with the DASP's Git repository on IPFS. 

### Developer Tools

The developer tools is used for deploying DASPs onto the Ethereum blockchain. It is based on Truffle and node.js. Currently, it can only be used via command line, but an UI will be built in the near future.