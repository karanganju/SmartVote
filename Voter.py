from ethereum import utils
import hashlib
import sha3
import random
import OpenSSL
import pyelliptic
import numpy as np
import Crypto.Random.random as Rand

# Shuffled votes are not signed at this point - Needs to be done

def generate_nonce(length=8):
    return ''.join([str(Rand.randint(0, 9)) for i in range(length)])


# This contains the list of al voters for communication.
# In a real scenario, the contract should have the 
class Election:
	participants = {}
	keys = {}
		

class Vote:
	def __init__(self, _nonce, _choice):
		self.nonce = _nonce
		self.choice = _choice
		s = hashlib.sha3_256()
		s.update(str(self.choice).encode())
		s.update(self.nonce)
		self.hash = s.hexdigest()
		print "Hash obtained is", self.hash

class Voter:
	def __init__(self, client_id, contract, state):
		self.id = client_id
		self.pub_addr = utils.privtoaddr(client_id)
		self.contract = contract
		self.contr_state = state
		self.hub_num = -1
		self.hub_id = -1
		self.key = pyelliptic.ECC()
		self.shuffled_hashes = []
		self.shuffled_votes = []
		# print self.shuffled_hashes

	# 1. Register to smart contract with public key and some amount/bid
	# 2. Get an id and voting hub along with addresses of the rest (or just the previous) (This can be used to pass the encyption keys and addresses of all previous hub members)
	def register(self, v):
		(self.hub_num, self.hub_id) = self.contract.join(self.key.get_pubkey().encode('hex'), value = v, sender = self.id)
		Election.participants[(self.hub_num, self.hub_id)] = self
		Election.keys[(self.hub_num, self.hub_id)] = self.key.get_pubkey()

	# Create nonce, choice and hash for vote
	def prepare_vote(self, choice):
		self.vote = Vote(generate_nonce(), choice)

	def send_shuffled_hash(self, next_voter):
		next_voter.shuffled_hashes = self.shuffled_hashes

	def send_shuffled_vote(self, next_voter):
		next_voter.shuffled_votes = self.shuffled_votes

	def shuffle_nonces(self):
		round_ciphertext = self.vote.hash + "|" + self.vote.nonce + "|" + str(self.vote.choice) + "|"
		for i in range(self.hub_id):
			round_ciphertext = self.key.encrypt(round_ciphertext, Election.keys[(self.hub_num, i)])
		self.shuffled_votes = [self.key.decrypt(x) for x in self.shuffled_votes]
		self.shuffled_votes.append(round_ciphertext)
		# Randomize array elements
		Rand.shuffle(self.shuffled_votes)
		if (self.hub_id == 0):
			hub_votes = ""
			for elem in self.shuffled_votes:
				hub_votes += elem + ","
			self.contract.open_hashes(hub_votes, self.hub_num, sender = self.id)			
		else:
			self.send_shuffled_vote(Election.participants[(self.hub_num, self.hub_id - 1)])

	def shuffle_hashes(self):
		round_ciphertext = self.vote.hash
		for i in range(self.hub_id):
			round_ciphertext = self.key.encrypt(round_ciphertext, Election.keys[(self.hub_num, i)])
		self.shuffled_hashes = [self.key.decrypt(x) for x in self.shuffled_hashes]

		self.shuffled_hashes.append(round_ciphertext)
		# Randomize array elements
		Rand.shuffle(self.shuffled_hashes)
		# print self.shuffled_hashes
		if (self.hub_id == 0):
			hub_votes = ""
			for elem in self.shuffled_hashes:
				hub_votes += elem + ","
			self.contract.submit_hashes(hub_votes, self.hub_num, sender = self.id)
		else:
			self.send_shuffled_hash(Election.participants[(self.hub_num, self.hub_id - 1)])

	def sign_shuffling(self, shuffled_hashes):
		for elem in shuffled_hashes:
			signed_hash = elem
			for i in range(self.hub_id):
				signed_hash = self.key.encrypt(round_ciphertext, Election.keys[(self.hub_num, i)])

		print "Vote has not been found!"	



		


	# # # # 
	# # # def revote():
	# def print_bal(self, stri):
	# 	print stri, self.contr_state.block.get_balance(self.pub_addr)