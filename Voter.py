from ethereum import utils
import hashlib
import pyelliptic
import Crypto.Random.random as Rand


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
		

# Contains the nonce, choice and hash of the vote
class Vote:
	def __init__(self, _nonce, _choice):
		self.nonce = _nonce
		self.choice = _choice
		s = hashlib.sha3_256()
		s.update(str(self.choice).encode())
		s.update(self.nonce)
		self.hash = s.hexdigest()

	def print_hash(self):
		print "SHA3 Hash :", self.hash

	def reveal(self):
		print "Nonce Used :", self.nonce
		print "Voted Candidate :", self.choice
		print "SHA3 Hash :", self.hash

	def toString(self):
		return self.hash + "|" + self.nonce + "|" + str(self.choice) + "|"

class Voter:
	def __init__(self, _name, client_id, _contract, _state):
		self.name = _name
		self.id = client_id
		self.pub_addr = utils.privtoaddr(client_id)
		self.contract = _contract
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
	# # # # 
	# # # def revote():