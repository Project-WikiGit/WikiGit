# WikiGit

World's first ecosystem for decentralized innovation & cooperation, powered by Ethereum.

The front end is at /client_ui/

The smart contracts are at /dev/contracts/

The developer tool is at /dev/

---

## Introduction

### The Vision

WikiGit implements an ecosystem for creating and interacting with what we call DASPs (Decentralized Autonomous Self-sustaining Projects). In the simplest terms, DASPs are an organic combination of DAOs (Decentralized Autonomous Organizations), coin offerings, crowdsourcing platforms (like Topcoder), and Git. The hope is that WikiGit will allow ingenious ideas to incarnate into projects that are self-sustaining in both finances and talent, with minimal cost and hindrances, similar to how Wikipedia allowed an entire encyclopedia to spontaneously come into being. In fact, it is possible that in the near future, WikiGit itself will be a DASP powered by WikiGit!

In its complete form, WikiGit will realize the following scenario: One person or more has a great idea, creates a DASP with a cost of ~US$5, writes a white paper or something similar that explains the idea, find some interested people online and add them into the DASP, pitch in/crowd fund some ether and post tasks onto the crowdsourcing platform; maybe personally contribute to the project; maybe recruit some interested freelancers as part-time or full-time contributors; and voila, a self-sustaining DASP is born, with its own funding, voting mechanism, contributors, freelancers, and shareholders, and the idea would blossom into something wonderful through the power of the crowd.

### The Project

<p align="center"> <img src="/assets/project_structure.png" alt="Project Structure"> </p>

The WikiGit project consists of three parts: the ***back end***, which is a set of Ethereum smart contracts that govern all of the core logics in a DASP; the ***front end***, which is a client-side web app that acts as a UI for interacting with the back end as well as a relay for connecting a DASP with its Git repository hosted by IPFS; and the ***developer tools***, which is an application for deploying a DASP onto the Ethereum blockchain. A particular DASP is defined by its back end, and different DASPs usually differ in their back ends; the front end and the developer tools are shared by all DASPs, although different implementations can be made as long as they are compatible with the back end's API.

### Project State

Currently, WikiGit is in its infant stages and is being worked by a handful of people. We have finished a preliminary implementation of the back end, a partial implementation of the front end (specifically the UI and back end for interacting with the IPFS Git repo and the member manifest) and the back end of the developer tools. We will do my best to find some more contributors, and anyone is welcome to join! (\***cough**\*you\***cough**\*)

---

## World's First Ecosystem for Decentralized Innovation & Cooperation

The WikiGit ecosystem contains three major components: ***Self-governing Projects, a Crowdsourcing Platform, and a Crowdfunding Platform***. Each of the components have been implemented individually before, but the existing products all fail to cooperate and form a complete ecosystem:

* **GitHub** has been the go-to place for hosting open source projects, with support for pull requests that utilize naïve crowdsourcing to help develop projects, as well as other project management tools (issues, projects, wiki, etc.) However, GitHub does not account for many other crucial parts of creating and maintaining a project, such as   

  * obtaining funding;
  * making collective decisions that shape the future of a project; 
  * providing financial incentives for contribution; 
  * systematically recognizing someone's contribution to the project.

* **Topcoder** is currently the prominent crowdsourcing platform for software development and UX design, where developers and designers compete to submit the best solution and receive the bounty. It has helped companies large and small to efficiently solve problems that they aren't familiar with/specialized in without the need to seek out full-time talents, as well as offers companies a new way of allocating project resources. However, Topcoder is less of a ***crowdsourcing*** platform and more of an ***outsourcing*** platform, because the companies and talents only have a tangential relationship, in that

  * talents can only work on relatively insignificant tasks nonessential to the companies' products, cannot continue working on projects they found interesting, and cannot join companies they found interesting;
  * companies do not have a formal channel for recruiting talent as full-time or part-time employees, and thus cannot rely on crowdsourcing as the main method for product development.

* **Kickstarter** is one of the most successful crowdfunding platforms, where creators with brilliant ideas can fund their projects through the financial support of people who love their ideas, and ordinary users can easily fund projects they find interesting and receive numerous benefits depending on the amount of their donation. However,

  *  Kickstarter patrons who have the necessary skills cannot easily contribute to the project through means other than financial support, which is bad for both the patrons and the creators;
  * project teams are not necessarily transparent in sharing the state of their projects;
  * there is no formal way for patrons to suggest how the projects should be developed and influence the outcome of the projects.

* **Initial Coin Offering (ICO)** is a crowdfunding method not dissimilar to IPOs that recently emerged on the Ethereum blockchain, where project teams offer custom ERC20 tokens in exchange for Ether, a type of cryptocurrency. The tokens are usually claimed to have utility on the applications that the teams are building. Funders would judge a project's feasibility based on its whitepaper, the current state of the project, the roadmap, etc., and send Ether to the project's team during the ICO if they feel optimistic about the project's future. ICOs have seen amazing success, with small teams raising millions of US$ of funding, but it suffers many severe problems that most people in the space have observed:

  * any small team with a whitepaper and a good-looking website seem to have been able to raise millions, which many observers have claimed as "scammy", and in fact many of the projects *are* scams. This problem stems from the lack of transparency in the projects.
  * Most of the time, the applications that the project teams are building don't actually require a custom token to function, and Ether, the native currency of Ethereum, would easily suffice. This would lead to a fractured blockchain, where a user must hold a type of token for each application one is using.
  * IPO usually occurs before a team has any presentable product, and the uncertainty would a) scare many investors away and b) make it difficult for investors to determine the feasibility of a project.

  ​

  WikiGit aims to solve all of the abovementioned problems through organically combining self-governing projects, crowdsourcing, and crowdfunding to form a vibrant ecosystem for innovation & cooperation, where

  * project teams can easily obtain funding, recruit talented people, and use bounties to crowdsource tasks;
  * talents can do freelancing, work on projects they're excited about without any barriers, and join any project team with minimal red-tape;
  * contributors and patrons can vote on proposals to make decisions for the project, their votes are weighted by the amount of their contribution and investment, and neither party would be able to dominate the other;
  * investors can invest in projects with minimal risk and uncertainty, as everything in a project is transparent and instead of a single million-dollar ICO, a project will have many small-scale coin offerings spread out across different phases of the project.

  The details of the WikiGit ecosystem will be explained below.

### Contribution-based Fair Governance

In a DASP, members use voting sessions to make collective decisions about the project. Each member's vote is weighted not only by how much shares (tokens issued during coin offerings) they hold, but also the member's ***reputation score***: a metric for measuring how involved a member is with the project, determined mostly by the number of *tasks* a member has completed. 

Each member has two types of reputation: *good reputation* and *bad reputation*. A member can earn good reputation through completing tasks, and the amount rewarded depends on the difficulty of the task. A member would receive bad reputation when the member submits a task solution that's deemed malicious. A member's reputation score is specific to each DASP, but there will be a platform for viewing a user's reputation score in all of the DASPs they're in.

The reputation score can be used by project teams to determine, say, whether or not to add a user as a full/part time member. The hope is that the reputation system can

* incentivize users to contribute to projects they're passionate about, since a better reputation means more say in project decisions;
* incentivize users to behave honestly, since even a small amount of bad reputation may discourage project teams from recruiting a user, thus tainting all the good reputation a user have earned;
* incentivize users to complete all the low-hanging tasks to get a better overall reputation, so that even infant projects without existing funds can get tasks done by offering reputation rewards.

Of course, since reputation systems are complex and need thorough designing, the system described above is only an early version and may be subject to change.

A voting-based governing system where both financial support and actual contribution to the project are taken into account can, perhaps, be truly "fair", in that both the investors' and the contributors' interests are represented, instead of only the investors' interests---what we have in today's corporate world.

### Zero-barrier Crowdsourcing & Talent Recruitment

In WikiGit, a user can choose to complete any task on the crowdsourcing platform as a freelancer and get paid, without asking for any authorization etc.. This is the existing norm on crowdsourcing platforms, but what differentiates WikiGit is that it's project-centered rather than task-centered, meaning that the user can continue working on a particular project if they found it interesting, and even attempt to join the project team backed by all the reputation they earned through completing tasks. Coupled with the fact that users are incentivized to discover projects and freelance for them, the WikiGit ecosystem automatically pairs users with projects they would be interested in, which in turn solves the problem of finding talent for projects.

### Transparent & Effective Coin Offerings 

TBD

### Endless Customization Choices

TBD

---

## Technical Details

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

The front end is a client-side web app that will be hosted on the IPFS network. It is the gateway for the members of a DASP to interact with it, as well as what a DASP would use to add/remove modules from the back end.

The front end uses web3.js to communicate with a DASP's back end, and gift (a wrapper for the Git CLI) & js-ipfs-api to communicate with the DASP's Git repository on IPFS. 

The front end includes a daemon, which uses all of the node.js modules mentioned above to connect a DASP with its Git repo. It works like this: the daemon listens for the TaskSolutionAccepted() event from the GitHandler module in the back end. Upon such an event, the daemon would clone the DASP's Git repo, pull from the updated repo where the task has been completed to merge the solution into the DASP's repo, publish the resulting repo onto IPFS, and send its IPFS multihash back to GitHandler as the current location of the DASP's repo. The ideal process would be where a solution's submitter can only upload a Git patch instead of the entire repo, but due to the limitations of the gift module, this currently cannot be implemented.

### Developer Tools

The developer tools is used for deploying DASPs onto the Ethereum blockchain. It is based on Truffle and node.js. Currently, it can only be used via command line, but an UI will be built in the near future.

---

## Contact

Feel free to contact us at info@wikigit.org !
