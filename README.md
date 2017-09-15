# WikiGit

A PoC implementation of Decentralized Autonomous Projects.

The smart contracts are in /client/contracts/



## Intro

​	WikiGit implements, in the simplest terms, an organic combination of DAOs (Decentralized Autonomous Organizations), freelancing platforms (like Topcoder), and Git. We call this combination DAPs (Decentralized Autonomous Projects). The hope is that WikiGit will allow ingenious ideas to incarnate into projects that are self-sustaining in both finances and talent, with minimal cost and hindrances, similar to how Wikipedia allowed an entire encyclopedia to spontaneously come into being. In fact, it is possible that in the near future, WikiGit itself will be a project powered by WikiGit!

​	WikiGit consists of three components: The logic component, which is a group of Ethereum smart contracts that handles most of the DAP's logic; the storage component, which stores the DAP's Git repository and some other data, and is based on decentralized storage solutions like Swarm and IPFS; and the UI component, which allows users to easily interact with the project, hosts the Git implementation, handles the communication between the other two layers, and implements some additional features, such as project management and forums.

​	In its complete form, WikiGit will realize the following scenario: One person or more has a great idea, creates a DAP with a cost of ~US$5, writes a white paper or something similar that explains the idea, find some interested people online and add them into the DAP, pitch in/crowd fund some ether and post tasks onto the freelancing platform; maybe personally contribute to the project; maybe recruit some interested freelancers as part-time or full-time contributors; and voila, a self-sustaining DAP is born, with its own funding, voting mechanism, contributors, freelancers, and shareholders, and the idea would blossom into something wonderful through the power of the crowd.

​	Currently, WikiGit is in its infant stages and is being worked by just one guy (me). I have finished an early implementation of the logic component, namely the Ethereum smart contracts, and hope to start working on the other two components some time soon. I will do my best to find some more contributors, and anyone is welcome to join! (\***cough**\*you\***cough**\*)



## The Logic Component (AKA Smart Contracts)

​	The logic component includes a DAO with a fully fledged voting mechanism; a vault that allows for the safe withdrawl of funds, as well as reactive token minting that can be used for stuff like ICOs and honorary tokens (such as the unicorn token issued to people who donated to the Ethereum project); a tasks handler for publishing tasks and accepting solutions on the freelancing platform; and a Git handler for communicating with the Git repository hosted by the storage component.

​	All of the core smart contracts mentioned above were designed as individual modules. This design allows for both updating the code down the road via contract swapping, and introducing new functionalities via adding lightweight modules in order to prevent frequent updates of the heavyweight core contracts. Even though the frequent intercontract communication of a modularized design entails costing more gas during normal usage than a single-contract infrastructure, the benefits of this design means that it's a lot more easier to maintain, update, and debug such systems, which makes large-scale, complex DAPs possible.

​	Also, the modularized design means that it is possible to swap out a core module for something compatible with any third-party app of your choosing. For instance, you can replace the task handler module for a contract that publishes task listings onto a third-party platform.

​	Due to the fact that it's infeasible to have an on-chain Git implementation, Git would have to be hosted by the off-chain UI that interacts with the on-chain logic.

​	For more information, just check out the code! All of the contracts were written with readability in mind and have been well commented, so it'd be a treat for those who prefer code to English.



## Contact

Feel free to contact me at zeframlou@gmail.com