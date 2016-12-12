pragma solidity ^0.4.2;

contract SmartVote {

	enum VotePhase {Uninitialized, Joining, Voting, Completed}

	struct _voter {
	
		address repr;
		uint point_of_contact;
		uint hub;
		uint hub_id;
		string enc_key;
	
	}

	struct _hub {

		uint size;
		mapping(uint => address) voters;

	}

	struct _vote {

		bytes vote_hash;
		bytes nonce;
		bytes choice;
		uint hub;
	
	}

	address public organizer;
	string public desc;
	VotePhase public phase;

	mapping(address => _voter) voters;
	mapping(uint => _hub) hubs;
	
	_vote[] votes;
	mapping(bytes => uint) vote_id;

	uint public min_bid;
	uint public ether_pool;
	uint public reward_pool;
	uint num_voters;
	uint num_votes;
	uint num_hubs;
	uint hub_max_size;

	event print_str(string inp);
	event print_int(uint inp);
	event print_byte(byte inp);

	function SmartVote() {
		organizer = msg.sender;
		ether_pool = 0;
		reward_pool = 0;
		num_voters = 0;
		num_hubs = 0;
		phase = VotePhase.Uninitialized;
		num_votes = 0;
	}

	function init_params(string _desc, uint _min_bid, uint _hub_size) {
		if (phase != VotePhase.Uninitialized || msg.sender != organizer) throw;
		phase = VotePhase.Joining;
		desc = _desc;
		min_bid = _min_bid;
		hub_max_size = _hub_size;
	}

	function die () {
		if (organizer == msg.sender) {
			suicide(organizer);
		}
		else throw;
	}

	function alloc_hub(address _voter_add) private returns (uint, uint) {
		if(hubs[num_hubs].size == hub_max_size) {
			hubs[++num_hubs] = _hub(0);
		}
		uint num_voter = hubs[num_hubs].size++;
		hubs[num_hubs].voters[num_voter] = _voter_add;
		return (num_hubs, num_voter);
	}


	// Registration function - Assign voter to a hub and collect encryption keys from voters for shuffle
	// Returns hub number which can be used to get hub information
	function join(string enc_key) payable returns (uint, uint) {
		if (voters[msg.sender].repr != 0) throw;
		if (msg.value != min_bid) throw;
		if (phase != VotePhase.Joining) throw;

		ether_pool += msg.value;
		uint hub_num;
		uint hub_id;
		(hub_num, hub_id) =  alloc_hub(msg.sender);
		voters[msg.sender] = _voter(msg.sender, num_voters++, hub_num, hub_id, enc_key);
		return (hub_num, hub_id);
	}

	// Check signatures of all hub participants
	// Store these nonces in a DS for public display
	function submit_hashes(string str_inp, uint hub_num) {
		uint last = 0;
		bytes memory inp = bytes(str_inp);
		uint len = inp.length;
		for(uint i = 0; i < len; i++) {
			if (inp[i] == ',') {
				bytes memory new_hash = new bytes(i - last);
				for(uint j = last;j < i;j++) new_hash[j-last] = inp[j];
				votes.push(_vote(new_hash, new bytes(0), new bytes(0), hub_num));
				num_votes++;
				vote_id[new_hash] = num_votes;
				last = i+1;
			}
		}
	}

	// Store nonce and choice in corresponding map entry
	// Check for digital signature here as well
	function open_hashes(bytes inp, uint hub_num) {
		uint last = 0;
		uint len = inp.length;
		for(uint i = 0; i < len; i++) {
			if (inp[i] == ',') {
				bytes memory vote_concat = new bytes(i - last);
				for(uint j = last;j < i;j++) vote_concat[j-last] = inp[j];
				
				uint firstdelim = uint(-1);
				uint seconddelim = uint(-1);

				for(uint k = 0;k<vote_concat.length;k++) {
					if (vote_concat[k] == '|' && firstdelim == uint(-1)) firstdelim = k;
					else if (vote_concat[k] == '|' && seconddelim == uint(-1)) seconddelim = k;
				}

				bytes memory vote_hash = new bytes(firstdelim);
				bytes memory vote_nonce = new bytes(seconddelim - firstdelim -1);
				bytes memory choice = new bytes(vote_concat.length - seconddelim - 2);

				for(uint k2 = 0;k2<vote_concat.length;k2++) {
					if(k2 > seconddelim && k2 < vote_concat.length-1) choice[k2-seconddelim-1] = vote_concat[k2];
					else if(k2 > firstdelim && k2 < seconddelim) vote_nonce[k2-firstdelim-1] = vote_concat[k2];
					else if(k2 < firstdelim) vote_hash[k2] = vote_concat[k2];
				}

				// print_str(string(vote_hash));
				// print_str(string(vote_nonce));
				// print_str(string(choice));

				if (vote_id[vote_hash] == 0) throw;
				else {
					uint voter_num = vote_id[vote_hash] - 1; 
					votes[voter_num].nonce = vote_nonce;
					votes[voter_num].choice = choice;
				}

				last = i+1;
			}
		}	
	}
 
	function remove_invalid_votes() {
		// Send to TRUSTED HARDWARE = PWNAGE!
	}

	function tally() returns (bytes) {
		mapping(bytes => uint) counts;
		// THIS IS IT! ITS THE DAY YOU'VE ALL BEEN WAITING FOR!
		bytes max_choice = votes[0].choice;
		uint max_votes = 0;
		for(uint i = 0; i < votes.length; i++) if(votes[i].choice.length != 0) {
			counts[votes[i].choice]++;
			if (counts[votes[i].choice] > max_votes) {
				max_votes = counts[votes[i].choice];
				max_choice = votes[i].choice;
			}
		}
		return max_choice;
	}
}