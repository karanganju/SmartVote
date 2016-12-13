# SmartVote
## Introduction

Online voting has a lot of benefits as well as drawbacks but hopefully, with strong cryptography, the risk of online voting can be minimized. This project tries to implement a voting scheme atop of Ethereum as a smart contract. As far as possible, the project tries to allow for larger-scale elections (by scale, I mean number of people, not necessarily stakes) but there are many inherent flaws in the concept of online voting itself that degrade the possibilities of a fully virtual democracy.

#### __Why use the blockchain to host an election?__
* __Transparency__ - Everyone knows that which candidate won, by what margin he won. The open blockchain will allow anybody to inspect anomalies in the procedure which allows for off-chain rectification.

* __Integrity and Non-Repudiation__ - The very nature of the blockchain, utilizing private keys for signatures, enforces non-repudiation which prevents users from reclaiming their votes or bids for personal and greedy incentives.

* __Convenient Rewarding Mechanism__ - Sitting directly atop Ethereum, it is very simple to hand out rewards and allocate voting bids, containing real value, to candidates. These rewards could range from invested funds to best answer votes. A simpler rewarding mechanism could also provide scope for incentivized voting to increase turnout.

* __Verifiability__ - The lack of a “strong trusted third party” adds to the transparency and verifiability of the scheme. Watchdogs can be set up to monitor the state of the contract and code can be reviewed as the entire functionality of the contract is public.

#### __That being said, there are also many challenges/security concerns in utilizing the blockchain to host any election.__
* __Privacy__ - Privacy in an election is of the utmost importance. Open votes create opportunities for vote selling, harassment, coercion, voting not directly aligned to incentives, to say the least. Often, democratic elections allow for a third party (government/election committee) to know who voted for whom to allow for accountability but the best solution would be to assume everyone as adversaries and make data private from all. To add to the problems, the smart contract itself cannot host any secret data as any data held by the smart contract is visible to all. This creates a very challenging but interesting scenario for privacy. The votes will be be made private by the voters and for the voters, in our case, using decentralized shuffling.
* __Accountability__ - Given that the election sits atop of a pseudonomity-enabling cryptocurrency, there is no inherent sense of accountability as any individual can make up multitudes of addresses and vote multiple times. One vote per address can be enforced not one vote per person. This can be mitigated in one of two methods.
  * Have a registration elsewhere and only limit registration on the blockchain to a restricted subset of addresses.
  * Have a election fee for each vote. This would correspond to something like one coin one vote but it also favours the rich.
* __Voter Coercion__ - Elections generally assume a trusted environment for voting to prevent coercion and have counter measures for vote selling such as by not giving the voter any proof of whom he/she voted for (receipt-freeness). But in the digital setup, using a trusted environment is not an option so most of the online voting solutions solve this in 1 of 3 ways
  * Allot any number of invalid and 1 valid vote (which are only distinguishable to the election committee) to the voter during the time of registration. Whenever coerced, the voter can cast the invalid vote and even the vote buyer cannot know for sure which vote is invalid and which is not.
  * Have the voting booth encrypt the vote without the voter knowing the nonce utilized for the encryption. If the voter wishes to verify that his vote has been cast correctly, the nonce is revealed but the vote is cast away and the voter is asked to revote. In this manner, the voter cannot provide the coercer/buyer any proof of his final cast vote.
  * Allow for anonymous and private revoting channels which are verifiable in their functioning but do not reveal any information about the revotes apart from the final changed tallies. Note that transparency of revotes is not an option here and we have to assume a weaker model but we can still abide by the stronger model for the case where voters are not coerced.
  
__In this project, we specifically aim to solved the following challenges in allowing voting atop of Ethereum__
* __Privacy__ - Enable some form of verifiable privacy using a decentralized shuffling technique based on Coinshuffle
* __Voter Incentivization__ - Increase voter turnout using lottery systems
* __Accountability__ - Reduce the accountability problem in utilizing either of the two approaches 
* [Addres voter coercion by at least enforcing the third solution which despite being the weakest still guarantees some imporovements]

## Protocol description

We examine individual components corresponding to the different 
This may be split across multiple sections, try to be thorough and understandable.

You must include at least one figure to illustrate your idea.

## Analysis and evaluation

You must explain some way of “validating” your work. This should at least include a security analysis (similar to the Smart Contract project). May also include benchmarks, theorems, or simulations.

## Related Work

Briefly explain the main ideas and results in the most closely related work, and explain how your work is novel in comparison. A guideline is to have at least 10-30 citations in total, but don’t go “padding” your citations with less relevant things. For software projects this can be shorter, but still you must refer to related projects.
