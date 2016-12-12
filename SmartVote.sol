pragma solidity ^0.4.2;

contract SmartVote {
	
	// Utility concat function taken from stackoverflow
	function strConcat(string _a, string _b, string _c) internal returns (string){
	    bytes memory _ba = bytes(_a);
	    bytes memory _bb = bytes(_b);
	    bytes memory _bc = bytes(_c);
	    string memory abc = new string(_ba.length + _bb.length + _bc.length);
	    bytes memory babc = bytes(abc);
	    
	    uint k = 0;

	    for (uint i = 0; i < _ba.length; i++) babc[k++] = _ba[i];
	    for (i = 0; i < _bb.length; i++) babc[k++] = _bb[i];
	    for (i = 0; i < _bc.length; i++) babc[k++] = _bc[i];
	    
	    return string(babc);
	}
	
	function char(byte b) returns (byte c) {
	    if (b < 10) return byte(uint8(b) + 0x30);
	    else return byte(uint8(b) + 0x57);
	}

	function toString(address x) returns (string) {
	    bytes memory s = new bytes(40);
	    for (uint i = 0; i < 20; i++) {
	        byte b = byte(uint8(uint(x) / (2**(8*(19 - i)))));
	        byte hi = byte(uint8(b) / 16);
	        byte lo = byte(uint8(b) - 16 * uint8(hi));
	        s[2*i] = char(hi);
	        s[2*i+1] = char(lo);            
	    }
	    return string(s);
	}

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

				print_str(string(vote_hash));
				print_str(string(vote_nonce));
				print_str(string(choice));

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

// 	function host(string desc, uint voting_period, uint joining_period) payable returns (string) {
// 		if (elections[msg.sender].host != 0 && elections[msg.sender].phase != VotePhase.Completed) throw;
// 		else {
// 			if (elections[msg.sender].host == 0) hosts_list.push(msg.sender);
// 			address[] memory empty_array;
// 			elections[msg.sender] = _election({host: msg.sender, desc: desc, phase: VotePhase.Joining, bid_pool: msg.value, voting_period: voting_period, joining_period: joining_period, candidates_list: empty_array});
// 		}
// 	}

// 	function join(address host, string proof) payable {
// 		if (elections[host].host == 0) throw;
// 		if (elections[host].phase != VotePhase.Joining) throw;

// 		elections[host].bid_pool += msg.value;
// 		elections[host].candidates[msg.sender] = _candidate({repr: msg.sender, pow: proof, votes: 0});
// 		elections[host].candidates_list.push(msg.sender);
// 	}

// 	function vote(address host, address candidate) {
// 		if (elections[host].host == 0) throw;
// 		if (elections[host].candidates[candidate].repr == 0) throw;
// 		if (elections[host].phase == VotePhase.Joining && now >= elections[host].joining_period) elections[host].phase = VotePhase.Voting;
// 		if (elections[host].phase != VotePhase.Voting) throw;

// 		elections[host].candidates[candidate].votes++;
// 		elections[host].voting_period = now + elections[host].voting_period;
// 	}

// 	function reward(address host) returns (address) {
// 		if (elections[host].host == 0) throw;
// 		if (elections[host].phase == VotePhase.Voting && now >= elections[host].voting_period) elections[host].phase == VotePhase.Completed;
// 		if (elections[host].phase != VotePhase.Completed) throw;
// 		if (elections[host].candidates_list.length == 0) throw;

// 		uint i;
// 		address winner = elections[host].candidates_list[0];
// 		for(i = 0; i < elections[host].candidates_list.length; i++) {
// 			address cand_iter = elections[host].candidates_list[i];
// 			if (elections[host].candidates[cand_iter].votes > elections[host].candidates[winner].votes) winner = cand_iter;
// 		}

// 		return winner;
// 	}

// }

// contract SmartVote is SmartVote {
	
// 	function SmartVote() {}

// 	function get_candidates(address host, uint start) returns (string) {
// 		string memory pows;
// 		address bidder;

// 		uint i;
// 		bool first = true;

// 		for(i = 0; i < 10; i++) {
// 			if (i+start >= elections[host].candidates_list.length) break;
// 			bidder = elections[host].candidates_list[start+i];
// 			if (first) {
// 				first = false;
// 				pows = elections[host].candidates[bidder].pow;
// 			}
// 			else {
// 				pows = strConcat(pows, "\n", elections[host].candidates[bidder].pow);
// 			}
// 			pows = strConcat(pows, " : ", toString(bidder));
// 		}

// 		return pows;
// 	}

// 	function get_host_add(uint start) returns (string) {
// 		string memory descriptions;
// 		address host;

// 		uint i;
// 		bool first = true;

// 		for(i = 0; i < 10; i++) {
// 			if (i+start >= hosts_list.length) break;
// 			if (elections[hosts_list[i+start]].phase != VotePhase.Joining) {
// 				start++;
// 				i--;
// 				continue;
// 			}
// 			host = hosts_list[i+start];
// 			if (first) {
// 				descriptions = elections[host].desc;
// 				first = false;
// 			}
// 			else {
// 				descriptions = strConcat(descriptions, "\n", elections[host].desc);
// 			}
// 			descriptions = strConcat(descriptions, " : ", toString(host));

// 		}

// 		return descriptions;
//	 }
// }