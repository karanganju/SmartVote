from ethereum import tester
from ethereum import utils
from Voter import *

election_host = tester.k0

state = tester.state()
contract = state.abi_contract(open('SmartVote.sol').read(), language='solidity', sender=election_host)

contract.init_params("President of the United States", 1000000, 4, sender=election_host)

v1 = Voter(tester.k1, contract, state)
v2 = Voter(tester.k2, contract, state)
v3 = Voter(tester.k3, contract, state)
v4 = Voter(tester.k4, contract, state)
v5 = Voter(tester.k5, contract, state)
v6 = Voter(tester.k6, contract, state)

v1.register(1000000)
v2.register(1000000)
v3.register(1000000)
v4.register(1000000)
v5.register(1000000)
v6.register(1000000)

v1.prepare_vote("Trump")
v2.prepare_vote("Trump")
v3.prepare_vote("Trump")
v4.prepare_vote("Trump")
v5.prepare_vote("Trump")
v6.prepare_vote("Hillary")

v4.shuffle_hashes()
v3.shuffle_hashes()
v2.shuffle_hashes()
v1.shuffle_hashes()
v6.shuffle_hashes()
v5.shuffle_hashes()

# # Have any revotes at this point in time

v4.shuffle_nonces()
v3.shuffle_nonces()
v2.shuffle_nonces()
v1.shuffle_nonces()
v6.shuffle_nonces()
v5.shuffle_nonces()

# contract.remove_invalid_votes(sender=election_host)
winner = contract.tally(sender=election_host)
print winner, "has won the election!"







































# q1 = QClient(tester.k1, contract, state)
# q2 = QClient(tester.k2, contract, state)
# q3 = QClient(tester.k3, contract, state)
# a4 = AClient(tester.k4, contract, state)
# a5 = AClient(tester.k5, contract, state) 
# a6 = AClient(tester.k6, contract, state)
# a7 = AClient(tester.k7, contract, state)
# a8 = AClient(tester.k8, contract, state)

# # This is the simple generic case where everyone knows and plays by the rules and people act to vote the best answer which may
# # or may not be aligned to their interests

# q1.print_bal("q1:")
# a4.print_bal("a4:")
# a5.print_bal("a5:")
# a6.print_bal("a6:")
# a7.print_bal("a7:")
# print "contract:", state.block.get_balance(contract.address)

# print q1.host("What ended in 1945?", 10, 100)

# # This period will now be the joining period. 

# a4.join(q1, "THE NAZI DREAM!", 2000000000000)
# a5.join(q1, "World War II", 2000000000000)

# state.mine(1)

# a6.join(q1, "World War I", 2000000000000)

# state.mine(8)

# a7.join(q1, "1944", 2000000000000)

# state.mine(2)

# a4.vote(q1, a5)

# # The voting period starts after the previous vote

# state.mine(2)

# q1.vote(a5)
# a7.vote(q1, a7)
# state.mine(2)

# a5.vote(q1, a5)
# state.mine(2)

# q1.print_bal("q1:")
# a4.print_bal("a4:")
# a5.print_bal("a5:")
# a6.print_bal("a6:")
# a7.print_bal("a7:")
# print "contract:", state.block.get_balance(contract.address)

# a7.reward(q1)

# # Voting period now has ended

# q1.print_bal("q1:")
# a4.print_bal("a4:")
# a5.print_bal("a5:")
# a6.print_bal("a6:")
# a7.print_bal("a7:")
# print "contract:", state.block.get_balance(contract.address)