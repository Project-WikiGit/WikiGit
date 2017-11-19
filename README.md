# WikiGit

World's first ecosystem for decentralized innovation & cooperation, powered by Ethereum.

**TL;DR:** WikiGit empowers projects with governing, crowdsourcing, and crowdfunding mechanisms, which form reinforcement loops that provide projects with rapid and sustainable growth from their moments of creation.

## Introduction

### The Vision

WikiGit implements an ecosystem for creating and interacting with what we call **Decentralized Autonomous Self-sustaining Projects (DASPs)**. In the simplest terms, a DASP is a reputation-based decentralized organization that comes with its own Git repository, governing mechanism, crowdfunding mechanism, and crowdsourcing mechanism. By offering any project with governmental infrastructure as well as funding and recruiting resources which are comparable to those available to giant corporations, WikiGit will allow ingenious ideas to swiftly incarnate into full-fledged projects that are self-sustaining in both finances and talent, with minimal cost and hindrances, similar to how Wikipedia allowed an entire encyclopedia to spontaneously come into being. In fact, in the near future the WikiGit project itself will be a DASP powered by WikiGit.

In its complete form, WikiGit will realize the following scenario: One or more person has a great idea, creates a DASP with a cost of ~US$1, writes a white paper or something similar that explains the idea, finds some likeminded people online to form an initial team, pitch in and/or crowdfund some Ether and use them to post tasks onto the crowdsourcing platform, personally contribute to the project and/or recruit some interested freelancers as part-time or full-time contributors; and voila, a self-sustaining project is born, with its own funding, government, contributors, freelancers, and shareholders, and the initial idea would blossom into something wonderful through the power of the crowd.

### The Project

<p align="center"> <img src="/assets/project_structure.png" alt="Project Structure"> </p>

The WikiGit project consists of three parts: the ***back end***, which is a set of Ethereum smart contracts that govern all of the core logics in a DASP; the ***front end***, which is a client-side web app that acts as a UI for interacting with the back end as well as a relay for connecting a DASP with its Git repository hosted by IPFS; and the ***developer tools***, which is an application for deploying a DASP onto the Ethereum blockchain. A particular DASP is defined by its back end, and different DASPs usually differ in their back ends; the front end and the developer tools are shared by all DASPs, although different implementations can be made as long as they are compatible with the back end's API.

### Project State

Currently, WikiGit is in its early stages and is being worked by a handful of people. We have finished a preliminary implementation of the back end, a partial implementation of the front end (specifically the UI and back end for interacting with the IPFS Git repo and the member manifest) and the back end of the developer tools. We will do my best to find some more contributors, and anyone is welcome to join! (\***cough**\*you\***cough**\*)

## Usage

### Front End UI

#### Prerequisites

* Node.js ^6.11.0
* Meteor ^1.5.2.2
* Coffeescript ^ 2.0.1
* Browser with web3.js support

#### Running

Under /client_ui/, enter the following in command line:

> npm install
>
> meteor run

The UI would be running at http://localhost:3000

Note: you need the back end smart contracts deployed on the current network first in order to use the UI.

### Developer Tools

#### Prerequisites

* Node.js ^6.11.0
* Truffle ^4.0.1
* Coffeescript ^2.0.1
* TestRPC ^4.1.3 (or Geth)

#### Running

First, edit /dev/migrate/config.json to include desired migration parameters. Then, under /dev/, enter the following in command line:

> testrpc -l 6600000

Or, if you want to use Geth,

> geth -rpc -unlock 0

In a new command line instance, enter

> npm install
>
> truffle migrate

The contracts would be deployed onto the specified network.

---

## The WikiGit Ecosystem, And Why It's Awesome

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
  *  project teams are not necessarily transparent in sharing the state of their projects;
  *  there is no formal way for patrons to suggest how the projects should be developed and influence the outcome of the projects.

* **Initial Coin Offering (ICO)** is a crowdfunding method not dissimilar to IPOs that recently emerged on the Ethereum blockchain, where project teams offer custom ERC20 tokens in exchange for Ether, a type of cryptocurrency. The tokens are usually claimed to have utility on the applications that the teams are building. Funders would judge a project's feasibility based on its whitepaper, the current state of the project, the roadmap, etc., and send Ether to the project's team during the ICO if they feel optimistic about the project's future. ICOs have seen amazing success, with small teams raising millions of US$ of funding, but it suffers many severe problems that most people in the space have observed:

  * any small team with a whitepaper and a good-looking website seem to have been able to raise millions, which many observers have claimed as "scammy", and in fact many of the projects *are* scams. This problem stems from the lack of transparency in the projects.
  * Most of the time, the applications that the project teams are building don't actually require a custom token to function, and Ether, the native currency of Ethereum, would easily suffice. This would lead to a fragmented blockchain, where a user must hold a type of token for each application one is using.
  * IPO usually occurs before a team has any presentable product, and the uncertainty would a) scare many investors away and b) make it difficult for investors to determine the feasibility of a project.


WikiGit aims to solve all of the abovementioned problems through organically combining self-governing projects, crowdsourcing, and crowdfunding to form a vibrant ecosystem for innovation & cooperation, where

  * project teams can easily obtain funding, recruit talented people, and use bounties to crowdsource tasks;
  * talents can do freelancing, work on projects they're excited about without any barriers, and join any project team with minimal red-tape;
  * contributors and patrons can vote on proposals to make decisions for the project, their votes are weighted by the amount of their contribution and investment, and neither party would be able to dominate the other;
  * investors can invest in projects with minimal risk and uncertainty, as everything in a project is transparent and instead of a single million-dollar ICO, a project will have many small-scale coin offerings spread out across different phases of the project.

The details of the WikiGit ecosystem will be explained below.

### Contribution-based Fair Governance

In a DASP, members use voting sessions to make collective decisions about the project. Each member's vote is weighted not only by how much shares (tokens issued during coin offerings) they hold, but also the member's ***reputation score***: a metric for measuring how involved a member is with the project, determined mostly by **the number of tasks** a member has completed. 

Each member has two types of reputation: *good reputation* and *bad reputation*. A member can earn good reputation through completing tasks, and the amount rewarded depends on the difficulty of the task. A member would receive bad reputation when the member submits a task solution that's deemed malicious. A member's reputation score is specific to each DASP, but there will be a platform for viewing a user's reputation score in all of the DASPs they're in.

The reputation score can be used by project teams to determine, say, whether or not to add a user as a full/part time member. The hope is that the reputation system can

* incentivize users to contribute to projects they're passionate about, since a better reputation means more say in project decisions;
* incentivize users to behave honestly, since even a small amount of bad reputation may discourage project teams from recruiting a user, thus tainting all the good reputation a user have earned;
* **incentivize users to complete all the low-hanging tasks across DASPs to get a better overall reputation, so that**
  * **users are encouraged to discover different projects, and**
  * **even infant projects without existing funds can get tasks done by offering reputation rewards.**

Of course, since reputation systems are complex and need thorough designing, the system described above is only an early version and may be subject to change.

A voting-based governing system where both financial support and actual contribution to the project are taken into account can, perhaps, be truly "fair", in that both the investors' and the contributors' interests are represented, instead of only the investors' interests---what we have in today's corporate world.

### Zero-barrier Crowdsourcing & Talent Recruitment

In WikiGit, a user can choose to complete any task on the crowdsourcing platform as a freelancer and get paid, without asking for any authorization etc.. This is the existing norm on crowdsourcing platforms, but what differentiates WikiGit is that WikiGit is project-oriented rather than task-oriented, meaning that the user can continue working on a particular project if they found it interesting, and even attempt to join the project team backed by all the reputation they earned through completing tasks. 

**Coupled with the fact that users are incentivized to discover projects and freelance for them (see *Contribution-based Fair Governance*, 3rd paragraph), the WikiGit ecosystem automatically pairs users with projects they would be interested in, which in turn solves the problem of finding talents for DASPs.**

### Transparent & Effective Coin Offerings 

WikiGit DASPs use coin offerings as the main method for funding the projects. Compared to the traditional projects that use ICOs to fund themselves after they have their white papers and minimalistic websites, DASPs have the following advantages when it comes to funding:

* When evaluating the state of a project, investors can base their decisions on maximal information gathered from looking at the project's Git repo, checking out current task listings, and viewing the team members' reputation and contribution history. This ensures that investors can make far more educated and low-risk decisions, and that only honest projects with active development can stand out to investors.
  * In contrast, a traditional ICO only provides investors with the team's grand vision and some rough roadmap, and at most some generic descriptions of the work currently being done. Yikes.
* DASPs can use multiple small-scale coin offerings spread throughout different phases of the project as their source of funding, rather than single million-dollar ICOs held before the project team had even made any tangible progress. It cannot be more obvious that investing in DASPs' coin offerings has far lower uncertainty and risk for investors than investing in ICOs.
* The tokens offered by DASPs have intrinsic value, in that holders can use them as votes during DASP voting sessions and influence the future of the projects.
  * In contrast, the value of most ICO tokens come from vague promises of future utility in the dApps the teams may or may not be building, and most project teams can't even justify why their dApps can't just use Ether instead of their custom tokens. This trend can lead to the fragmentation of the Ethereum blockchain, which will force future users to hold a different token for each dApp they use.

In conclusion, DASP coin offerings are low-risk and low-uncertainty for investors, and the transparency of DASPs ensures that only honest projects can get funding from investors.

### Customization & Expandability

Virtually all parameters of a DASP---length of a voting session, rights of different member groups, etc.--- are designed to be customizable, in that all one needs to do to change a certain parameter is to start a voting session. Also, since DASPs are essentially smart contracts, WikiGit allows project teams to customize literally every last detail of their DASPs via altering the contract code, as long as the contracts remain compatible with the rest of the ecosystem.

WikiGit also allows DASPs to plug in third party modules to expand their functionalities, so the possibilities are endless. Here are a few examples:

* A DASP can connect its task listings with a third party crowdsourcing platform, so that its talent pool is larger.
* A DASP can be connected to a prediction market that predicts which of the task solution submissions are likely to be accepted, so that the validators can have a heuristic for deciding which solutions are the best.
* A DASP can connect its reputation system with its discussion forum so that users who contribute valuable content are rewarded with good reputation, and users who violate the forum policies receive bad reputation.

We expect to see a new industry of DASPs that are dedicated to making custom modules, and it's possible that WikiGit will have a module manager similar to npm for Node.js and pip for Python.

## Contact

Feel free to contact us at info@wikigit.org !
