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
  
__In this project, we specifically aim to solve the following challenges in allowing voting atop of Ethereum__
* __Privacy__ - Enable some form of verifiable privacy using a decentralized shuffling technique based on Coinshuffle
* __Voter Incentivization__ - Increase voter turnout using lottery systems
* __Accountability__ - Reduce the accountability problem in utilizing either of the two approaches 
* [__Coercion__ - Addres voter coercion by at least enforcing the third solution which despite being the weakest still guarantees some imporovements]

## Protocol description and Security Analysis

We examine individual components corresponding to the different goals and give their security analysis correspondingly.

### Privacy

As we discussed previously, the smart contract cannot create any secret data so traditional solutions such as encrypting votes, sending them to the smart contract and permutating the votes and opening them (read: Helios) do not work here. Instead, we use the very elegant solution provided by CoinShuffle which is used to create anonymous Bitcoin addresses. We use a similar solution which we enumerate below.

1. During registration, each voter is assigned a hub and a hub ID. These hubs are aggregation of voters who will shuffle votes in a fixed order as specified by the hub ID.
2. Each voter prepares a vote-string (a string representing the candidate to vote for), a nonce and a hash of the two strings (we use SHA3-256)
3. According to hub IDs, each voter sequentially encrypts his hash with the public key of the previous voters (ordered by hub ID and starting from the hub ID just before that of the voter - we'll assume the hub voters are arranged from 0 to max from left to right).
4. Starting from the rightmost voter, each voter decrypts all the hashes he is passed by the voter on his right (none for the last voter) using his own private key, appends his own encrypted hash to the set, randomly shuffles the hashes and passes them on to the voter on his left to repeat the same. In this way, each voter removes one layer of encryption and randomly shuffles votes without knowing who submitted which hash or what votes have been committed.
5. At the end of this, the voter with hub ID 0 receives all decrypted hashes.
6. Now starting from the left, each voter verifies that his hash is contained in the shuffled hashes and signs all the hashes with his private key. The rightmost voter is then assigned the task of sending this information to the smart contract.
7. The same rounds of shuffling and signing are repeated, this time using a concatenation of the hash string, the nonce string and the vote string instead of just the hash string. It is upon the the rightmost voter again to submit the opened commitments to the smart contract.
8. The smart contract each time checks that all the voters have signed the shuffled hashes/votes and then stores them.

In this way, the smart contract receives the votes in a privacy assuring manner. Now, we discuss many questions pertaining to the security analysis of this solution.


**_Voter Collusion?_**

If any hub contains a majority of colluded voters, they can reveal their shuffling to each other and effectively reduce the entropy/randomness to predict the voter for a particular hash/vote. This is an issue with shuffling techniques in general and hub allocation can be randomized to prevent colluders from landing in the same hub. Also, larger hubs make it more expensive for colluders to obtain meaningful data. Note that even if there are 2 honest shufflers, the colluding shufflers cannot determine entirely the vote belonging to any voter.

**_DOS?_**

It is very clear to see that any voter can DOS the system by not responding. This could happen even in the case where the voter is offline or unavailable at the time of shuffling (which would make the process very long where everyone has to wait for each other person to come back and shuffle and each voter has to interact 4 times in this process so things can get out of hand). There are some solutions to this although they have not been implemented
* Allocate some time for the election and only take votes from voters that are live/online. This would require voters to broadcast their availability and a public list (smart contract could be used) of live voters who would shuffle the votes amongst themselves. Anybody who still fails to do so would lose not only the election deposit but also their chance to vote by maintaining a blacklist. To prevent attackers from DOSing other voters by disrupting their network and effectively blacklisting them, more such voting rounds can be kept where these blacklisted voters get more chances.
* Keep a smaller hub size to prevent more disruptions due to unavailable voters.

Also, although the previous issue only deals with DOS attempts without any real incentives, recall that in the second shuffling, during the signing phase, every voter is able to derive the total tally of the hub and might have an incentive to DOS the voting for the hub if it does not favor his candidate. For this, we could employ either retries and blacklisting techniques or ignore the signing phase for the second shuffling entirely (see the last point below).

**_Effect of Hub Size?_**

There is a very apparent tradeoff between privacy and DOS resistance in changing the hub size. Too high or too low a value could be quite harmful and so one would wish to aim for a sweet spot in the middle and this could vary based on the nature of the election. For example, if the system is able to detect DOS attackers and watchdogs are efficient in monitoring network status and detecting anomalies, the hub size could be made larger to compromise on the DOS resistance to allow for better privacy guarantees. Also, hubs could be assigned randomly to mitigate against colluders.

**_Is 2 round shuffling necessary?_**

In this technique, yes. However, there are some other alternatives to the mechanism we are using.
* Shuffle and sign the hashes as before and open commitments through an anonymous channel like Tor
 * Assumes Tor is not broken.
* Shuffle and sign not the hashes but votes (with nonces) encrypted with the public key of a hub admin who opens the votes after shuffling is complete
 * Assumes that the hub admin does not collude with the first k leftmost voters (reasonable if hub assignment is random but the the hub admin can also buy obedience from the voters to satisfy his motives).
* Shuffle and sign not the hashes but votes that are encrypted using threshold encryption techniques, which requires a random set of voters to get together to open the votes - this set's size can be varied to prevent collusion (large size) while also allowing a live and active voter contribution to open the votes (smaller size to allow for unavailable voters)
 * This is the strongest model but requires more interaction from a set of voters which might hamper usability.

**_Is the reverse signing phase required?_**

For the first round, yes. But for the second round, if we assume the voter with hub ID 0 to be a hub admin who can be held accountable, he can send the opened commitments to the 

### Voter Incentivization

### Accountability

### Coercion


You must include at least one figure to illustrate your idea.

## Analysis and evaluation

The security analysis of individual components have been given previously. The files [safe_case.py, ...] can be seen to learn how the code runs. Also, the Voter class file and the smart contract solidity file have been well commented.

We analyze the test cases that are given with the code.

[]


## Related Work


