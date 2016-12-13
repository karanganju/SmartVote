from ethereum import utils
import hashlib
import pyelliptic
import Crypto.Random.random as Rand
from sets import Set


def generate_nonce(length=8):
    return ''.join([str(Rand.randint(0, 9)) for i in range(length)])

# This contains the list of al voters for communication.
# It is filled voluntarily by the voters for this implementation 
# but a better version would require it to take this from the contract itself
class Election:
	# Link from hub_num and hub_id to voter instance 
	# In an actual client implementation, this would only have a reference to a point of contact - ip/eth address to the voter for communication
	# WEAK POINT - Since we fill this voluntarily, a voter can fake his credentials or masquerade. Even if we filled this
	# through the smart contract, there would have to be a way to authenticate that it is the smart contract we are dealing with
	# One operational way to do this is to hand this responsibility to election commitee, which anyone can verify through the contract
	participants = {}
	# Link from hub_num and hub_id to voter key (the only public data about the voters)
	keys = {}
	# Deleted Votes
	del_votes = Set([])
	# Added Votes
	added_votes = Set([])
	# Tally map
	tallies = {}

# We check if the contract has the hash corresponding to the old vote. That's fine for the implementation but it is VERY wrong.
# Any coercer listening on the network can see this function call and detect that the voter is revoting.
# Instead we should download all hashes and check locally.
def send_revote(old_vote, new_vote, contract, organizer):
	if (old_vote.check_hash() and new_vote.check_hash()):
		if (old_vote not in Election.del_votes):
			if (old_vote in Election.added_votes or (contract.get_phase_and_check_hash(""+old_vote.hash, sender=organizer) == 1)):
				Election.del_votes.add(old_vote)
				Election.added_votes.add(new_vote)
				print "Somebody Revoted!"
				return 1
	return -1


def send_tallies(contract, organizer):
	for vote in Election.del_votes:
		if (vote.choice in Election.tallies.keys()):
			Election.tallies[vote.choice] -= 1;
		else:
			Election.tallies[vote.choice] = -1;

	for vote in Election.added_votes:
		if (vote.choice in Election.tallies.keys()):
			Election.tallies[vote.choice] += 1;
		else:
			Election.tallies[vote.choice] = 1;


	tally_counts = []
	choices = ""
	for elem in Election.tallies.keys():
		choices += elem + "|";
		tally_counts.append(Election.tallies[elem])

	return contract.send_revotes_and_tally(choices, tally_counts, sender=organizer)

# Contains the nonce, choice and hash of the vote
class Vote:
	def __init__(self, _nonce, _choice):
		self.nonce = _nonce
		self.choice = _choice
		s = hashlib.sha3_256()
		s.update(self.nonce+str(self.choice).encode())
		self.hash = s.hexdigest()

	def print_hash(self):
		print "SHA3 Hash :", self.hash

	def reveal(self):
		print "Nonce Used :", self.nonce
		print "Voted Candidate :", self.choice
		print "SHA3 Hash :", self.hash

	def check_hash(self):
		s = hashlib.sha3_256()
		s.update(self.nonce+str(self.choice).encode())
		if (s.hexdigest() == self.hash):
			return True;
		else:
			return False;

	def toString(self):
		return self.hash + "|" + self.nonce + "|" + str(self.choice) + "|"

class Voter:
	def __init__(self, _name, client_id, _contract, _state, _organizer):
		self.name = _name
		self.id = client_id
		self.pub_addr = utils.privtoaddr(client_id)
		self.contract = _contract
		self.organizer = _organizer
		self.state = _state
		# The hub this voter is assigned to (Hubs are used as shuffling groups)
		self.hub_num = -1
		# The hub id within the assigned hub (A strict order of shuffling is imposed)
		self.hub_id = -1
		# Key for encryption using ECC (ECIES)
		self.key = pyelliptic.ECC()
		# Used to capture shuffled commitments/votes through the shuffling phase
		self.shuffled_hashes = []
		self.shuffled_votes = []
		self.new_vote = 0

	# Register to be assigned a hub and broadcast your encyption details and point of contact (ip/ethereum address)
	def register(self, election_fee):
		(self.hub_num, self.hub_id) = self.contract.join(self.key.get_pubkey().encode('hex'), value = election_fee, sender = self.id)
		Election.participants[(self.hub_num, self.hub_id)] = self
		Election.keys[(self.hub_num, self.hub_id)] = self.key.get_pubkey()

	# Create nonce, choice and hash for vote
	def prepare_vote(self, choice):
		self.vote = Vote(generate_nonce(), choice)

	# Send shuffled encrypted hashes to next shuffler
	def send_shuffled_hash(self, next_voter):
		next_voter.shuffled_hashes = self.shuffled_hashes

	# Send shuffled encrypted open votes to next shuffler
	def send_shuffled_vote(self, next_voter):
		next_voter.shuffled_votes = self.shuffled_votes

	# Shuffle step for open votes
	def shuffle_votes(self):
		round_ciphertext = self.vote.toString()
		# Encrypt own vote 
		for i in range(self.hub_id):
			round_ciphertext = self.key.encrypt(round_ciphertext, Election.keys[(self.hub_num, i)])
		# Decrypt all received votes
		self.shuffled_votes = [self.key.decrypt(x) for x in self.shuffled_votes]
		# Append own vote and shuffle
		self.shuffled_votes.append(round_ciphertext)
		Rand.shuffle(self.shuffled_votes)
		# Send to next voter to shuffle and add his vote or send to the contract if shuffling is complete
		if (self.hub_id == 0):
			hub_votes = ""
			for elem in self.shuffled_votes:
				hub_votes += elem + ","
			self.contract.open_hashes(hub_votes, self.hub_num, sender = self.id)			
		else:
			self.send_shuffled_vote(Election.participants[(self.hub_num, self.hub_id - 1)])

	# Shuffle step for commitments
	def shuffle_hashes(self):
		round_ciphertext = self.vote.hash
		# Encrypt own commitment
		for i in range(self.hub_id):
			round_ciphertext = self.key.encrypt(round_ciphertext, Election.keys[(self.hub_num, i)])
		# Decrypt all received commitments
		self.shuffled_hashes = [self.key.decrypt(x) for x in self.shuffled_hashes]
		# Append own commitment and shuffle
		self.shuffled_hashes.append(round_ciphertext)
		Rand.shuffle(self.shuffled_hashes)
		# Send to next voter to shuffle and add his commitment or send to the contract if shuffling is complete
		if (self.hub_id == 0):
			hub_votes = ""
			for elem in self.shuffled_hashes:
				hub_votes += elem + ","
			self.contract.submit_hashes(hub_votes, self.hub_num, sender = self.id)
		else:
			self.send_shuffled_hash(Election.participants[(self.hub_num, self.hub_id - 1)])

	def print_bal(self):
		print self.name, "has balance :", self.state.block.get_balance(self.pub_addr)

	# Send revote to Election Committee through anonymous means. Only final tallies are shown in the contract.
	def revote(self, choice):
		new_vote = Vote(generate_nonce(), choice)
		if (self.new_vote == 0):
			old_vote = self.vote
		else:
			old_vote = self.new_vote
		if (send_revote(old_vote, new_vote, self.contract, self.organizer) == 1):
			self.new_vote = new_vote
			return 1;
		else:
			return 0
