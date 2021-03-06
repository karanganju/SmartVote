from ethereum import tester
from ethereum import utils
from Voter import *

election_host = tester.k0

state = tester.state()
contract = state.abi_contract(open('SmartVote.sol').read(), language='solidity', sender=election_host)

contract.init_params("President of the United States", 1000000, 4, 90, sender=election_host)

v1 = Voter("v1", tester.k1, contract, state, election_host)
v2 = Voter("v2", tester.k2, contract, state, election_host)
v3 = Voter("v3", tester.k3, contract, state, election_host)
v4 = Voter("v4", tester.k4, contract, state, election_host)
v5 = Voter("v5", tester.k5, contract, state, election_host)
v6 = Voter("v6", tester.k6, contract, state, election_host)

v1.print_bal()
v2.print_bal()
v3.print_bal()
v4.print_bal()
v5.print_bal()
v6.print_bal()

v1.register(1000000)
v2.register(1000000)
v3.register(1000000)
v4.register(1000000)
v5.register(1000000)
v6.register(1000000)

v1.print_bal()
v2.print_bal()
v3.print_bal()
v4.print_bal()
v5.print_bal()
v6.print_bal()

v1.prepare_vote("Trump")
v2.prepare_vote("Trump")
v3.prepare_vote("Trump")
v4.prepare_vote("Trump")
v5.prepare_vote("Trump")
v6.prepare_vote("Hillary")

contract.commence_voting(sender=election_host)

v4.shuffle_hashes()
v3.shuffle_hashes()
v2.shuffle_hashes()
v1.shuffle_hashes()
v6.shuffle_hashes()
v5.shuffle_hashes()

v4.revote("Hillary")
v5.revote("Hillary")
v2.revote("Hillary")

contract.commence_revealing(sender=election_host)

v4.shuffle_votes()
v3.shuffle_votes()
v2.shuffle_votes()
v1.shuffle_votes()
v6.shuffle_votes()
v5.shuffle_votes()

# contract.remove_invalid_votes(sender=election_host)
winner = send_tallies(contract,election_host)
print winner, "has won the election!"

(lwinner_hub_num, lwinner_hub_id) = contract.end_election(sender=election_host)
print Election.participants[(lwinner_hub_num, lwinner_hub_id)].name, "has won the lottery!!!"

v1.print_bal()
v2.print_bal()
v3.print_bal()
v4.print_bal()
v5.print_bal()
v6.print_bal()