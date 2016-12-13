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

This attack is showcased in DOS_attack.py.

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

For the first round, yes. But for the second round, if we assume the voter with hub ID 0 to be a hub admin who can be held accountable, he can check for all the hashes and send the opened commitments to the smart contract without the need of signing. Since all votes have already been committed to, he cannot change any hashes. Also, since all communication is public and through the Ethereum network, it will be evident if he *conveniently* drops any votes. This is a better system than the one proposed as there is no risk of the incentivized DOS attack talked about in the previous sections. Unfortunately, the implementation does not check for signatures and so suffers from the trivial attack shown in exploit_no_signature_checking.py.

### Voter Incentivization

For voter incentivization, we take a small amount off from the election fee and assign it as a lottery cut which is allotted to one single random voter. The issue now comes to pick a source of randomness. The parent blockhash can be used but for a large scale lottery system, miners have plenty of incentive to produce hashes which serve the purpose of getting them the lottery. However, we have an even better source of randomness. Recall that we pick up nonces from the voters at the time of opening the commitment. These nonces can be assumed as independently drawn and so almost mimic a true RNG. These nonces are xor-ed with each other and the taken modulo the number of voters to give a voter id which is selected as the lottery winner. This is a much better source of randomness if we assume that all the voters are not colluding which is a reasonable assumption.

Literature was quite divided on how effective lottery systems are in improving voting. While one side claims that this increases uneducated and unaware voters and thus decreases quality of voting, the other side claims that since the effective cost of voting has decreased due to benefits received, people will spend more on gaining awareness and thus, quality will improve. Clearly, there is a need to verify these notions experimentally.

The only vulnerable part in this component is either the lottery pool or the election fee that is collected. If an attacker is able to somehow find a bug in the program, he could potentially leak these funds into his/her own account (DAO). There seem to be no evident bugs in the code but a suicide function has been implemented which can only be called by the organizer and fetches all funds from the contract to the organizers account, which can then be returned to the respective voters. Note that the availability of this function is a dual-edged sword. It also means that the organizer could leak the funds before the lottery is returned or a candidate is voted. So, voters should know the organizer before allocating funds into the contract.

### Accountability

As discussed previously, there are 2 ways to do this.
* Keep a minimum election fee which is received from the voter. That makes the system follow the one coin one vote protocol and favours the rich. It is a weak system but at least is much better than not having it at all.
* A better solution would be to have some offline registration which would then only allow a decided set of addresses to participate in the voting system.

We have implemented the former although the latter can be just as easily implemented. The security analysis of this deals with leakage of election fees which has been discussed about earlier.

### Coercion

As discussed previously, voter coercion is a difficult problem to solve. Many existing solutions for online voting do not even address the problem of voter coercion because of its difficulty. All the 3 methods discussed above for online voting coercion resistance require some form of a trusted third party which results in loss of transparency and verifiability. But using the smart contract is not an option because, neither can it hold a list of invalid votes secretly, nor can it generate secret nonces and encrypt the voters choice privately and it definitely cannot store a set of revotes in any form of private memory. Hence, it is clear that some assumptions will have to be made. 

The solution we came up with was to allow a trusted third party, preferably in the form of a trusted hardware module which can be communicated with anonymously and can be sent revotes. A revote is simply maintained as a collection of the old vote and the new vote (including hash, nonce and choice strings). The trusted hardware checks if the old hash exists either in its own memory (which means the old vote itself is also a revote) or in the publicly store public shuffled commitments. If it does, it stores the mapping in its memory. At the end of the election, the trusted party calculates the change in tallies which will occur due to revotes (some votes will decrease and some will increase) and sends this to the smart contract which adds this to its own tally.

Clearly, this model lacks verifiability as the only data made public is the final tally of votes. One thing that can be allowed to slightly mitigate this is that voters can be allowed to query whether a certain mapping exists within the memory of the trusted hardware. If the coercers and the election committee/organizers collude, then this model will fail to provide any security guarantees.

![pic.png](https://s27.postimg.org/5xqfc6er7/pic.png)

## Analysis and evaluation

The security analysis of individual components have been given previously. The files [safe_case.py, DOS_attack.py, exploit_no_signature_checking.py] can be seen to learn how the code runs. Also, the Voter class file and the smart contract solidity file have been well commented. Security flaws have been identified and shown in the latter 2 files. Trivial edge cases have been identified and sorted out.

## Related Work

1. [CoinShuffle] (http://crypsys.mmci.uni-saarland.de/projects/CoinShuffle/coinshuffle.pdf)
 * We use the same concepts utilized in the paper to enable privacy.
2. [Helios] (https://files.t-square.gatech.edu/access/content/group/XLS0822120636201008.201008/adida.pdf)
 * Assumes a trusted environment and uses a private server for shuffling so one's vote is private only amongst his peer voters, not from the officials themselves.
 * Also uses shuffling for privacy of votes and allows voters to inspect votes (after which they will have to revote)
 * Voters cannot verify the final cast vote
3. [Bitcongress] (http://www.bitcongress.org/)
 * Propose a very different system which uses a different blockchain for voting (expensive) and have the concept of one cpu one vote (not very different from one coin one vote). 
 * Also, privacy is correlated with anonymity of cryptocurrency addresses which can only be justified if a separate blockchain is utilized.
4. OpenVote Network (Patrick McCorry's system)
 * Use a very different cryptographic construct (based on El Gamal encryptions) to provide privacy
 * Their runtime is almost similar in terms of number of rounds and/or user interaction but their final tally construction requires a exponential space search which seemed very inefficient.
 * Do not consider coercion at all
5. [Estonia] (https://jhalderm.com/pub/papers/ivoting-ccs14.pdf)
 * Allow for unlimited online revotes where only final revote is accepted.
 * Use private election servers
 * Little verifiability as not all code is open-source and is hosted on government-controlled servers
 * Security suffers due to election officials having too much power and being reckless (posting videos while typing the root password)
6. [Follow My Vote] (https://followmyvote.com/)
 * Also based on Ethereum
 * Details are not very clear but it seems that voter coercion is not handled and privacy is handled in the weaker case (not private to election organizers)

## SELF EVALUATION

* __What went well?__

I really really enjoyed doing the project (and the course). It was very technically challenging and quite open-ended (in hindsight maybe a bit too open-ended). Also I believe very firmly in the concept due to the benefits of verifiable privacy and transparency and also because with time everything is becoming digital. I never once thought that creating a voting scheme could be so difficult. Some years back I might even have laughed it off and told you to count the maximum votes given to a candidate. But this is really quite a relevant issue and requires some good amount of thought.


* __What didn’t go well?__

My timing and scheduling, probably. I spent too much time thinking and doing this solo, often I got lost in thinking about issues like voter coercion, which quite clearly have no simple answer and require some compromise somewhere. I feel that I am still not prepared yet to take up individual research projects. But it’s good that I realize my limitations. Hopefully, I can work on them in the coming semesters. For the project, I feel if I had a good partner, we could have come up with a great implementation.


* __Difference from Checkpoint Summary__

Most of the content remained the same as was proposed in the Checkpoint Summary. I have not deviated from the proposal but voter coercion resistance turned out to be quite challenging on its own. Voter rewarding turned out to be pretty trivial although an optimal implementation seems to require more game-theoretic analysis. It felt nice to come up with a rather clean solution for voter privacy on the blockchain (with your help). 
