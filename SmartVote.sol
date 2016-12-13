pragma solidity ^0.4.2;

contract SmartVote {

	enum VotePhase {Uninitialized, Joining, Secret, Open, Tallied, Terminated}

	// Store information about voter for reference
	struct _voter {
		// Eth address of voter
		address repr;
		// Point of contact of voter - This could be IP or something but is useless for now
		uint point_of_contact;
		// Hub assigned to voter along with hub_id
		uint hub_num;
		uint hub_id;
		// Encryption Key of voter required for shuffling
		string enc_key;
	}

	// Hub information - We maintain size and create new hubs if size exceeds the max size
	struct _hub {
		uint size;
		mapping(uint => address) voters;
	}

	// information about votes, this is most necessary
	struct _vote {

		bytes vote_hash;
		bytes nonce;
		bytes choice;
		uint hub_num;
	
	}

	// Hub and voter mappings
	mapping(address => _voter) voters;
	mapping(uint => address) voter_addr;
	mapping(uint => _hub) hubs;
	
	// Vote mappings
	_vote[] votes;
	mapping(bytes => uint) vote_id;

	// Election metadata
	address public organizer;
	string public desc;
	VotePhase public phase;

	uint public election_fee;
	uint public ether_pool;
	uint public lottery_pool;
	uint num_voters;
	uint num_votes;
	uint num_hubs;
	uint hub_max_size;
	// out of 100
	uint lottery_cut;
	uint random;

	event print_str(string inp);
	event print_int(uint inp);
	event print_byte(byte inp);

	// Initialize variables
	function SmartVote() {
		organizer = msg.sender;
		ether_pool = 0;
		lottery_pool = 0;
		num_voters = 0;
		num_votes = 0;
		num_hubs = 0;
		random = 0;
		phase = VotePhase.Uninitialized;
	}

	// Set election-defined variables. These can be varied as per type of election.
	function init_params(string _desc, uint _election_fee, uint _hub_max_size, uint _lottery_cut) {
		// This can only be done when the contract is freshly created and by the organizer
		if (phase != VotePhase.Uninitialized || msg.sender != organizer) throw;
		
		desc = _desc;
		election_fee = _election_fee;
		hub_max_size = _hub_max_size;
		phase = VotePhase.Joining;
		lottery_cut = _lottery_cut;
	}

	// Suicide Function - Return all funds to organizer to handle in offline manner 
	// (when bug is detected and contract cannot be trusted)
	// WEAK POINT - Voters should be aware of this functionality and alternative means 
	// for accountability of the organizer MUST be ensured
	function die () {
		if (organizer == msg.sender) {
			suicide(organizer);
		}
		else throw;
	}

	// Allocate hub and hub_id to voter - Cannot be called from outside hence smart contract data is pristine
	function alloc_hub(address _voter_add) private returns (uint, uint) {
		if(hubs[num_hubs].size == hub_max_size) {
			hubs[++num_hubs] = _hub(0);
		}
		uint num_voter = hubs[num_hubs].size++;
		hubs[num_hubs].voters[num_voter] = _voter_add;
		return (num_hubs, num_voter);
	}

	function toUint(bytes inp) returns (uint) {
		uint sum = 0;
		uint pow2 = 1;
		for(uint i = 0;i<inp.length;i++) {
			if (i > 7) break;
			sum += uint8(inp[i]) * pow2;
			pow2 = pow2 * 2**8;
		}
		return sum;
	}

	function commence_voting() {
		if (msg.sender != organizer) throw;
		if (phase == VotePhase.Joining) phase = VotePhase.Secret;
		else throw;
	}

	function commence_revealing() {
		if (msg.sender != organizer) throw;
		if (phase == VotePhase.Secret) phase = VotePhase.Open;
		else throw;
	}

	// Registration function - Assign voter to a hub and collect encryption keys from voters for shuffle
	// Returns hub_num and hub_id to the voter
	function join(string enc_key) payable returns (uint, uint) {
		// Throw if election has not been submitted or if Joining phase is over or if voter has already joined
		if (voters[msg.sender].repr != 0) throw;
		if (msg.value != election_fee) throw;
		if (phase != VotePhase.Joining) throw;

		// Take lottery cut from fees
		uint lottery_amount = ((msg.value*lottery_cut)/100);
		ether_pool += msg.value - lottery_amount;
		lottery_pool += lottery_amount;

		// Allocate and assign hub to the voter
		uint hub_num;
		uint hub_id;
		(hub_num, hub_id) =  alloc_hub(msg.sender);
		voter_addr[num_voters] = msg.sender;
		voters[msg.sender] = _voter(msg.sender, num_voters++, hub_num, hub_id, enc_key);
		return (hub_num, hub_id);
	}

	// Take all votes from a single hub
	function submit_hashes(string str_inp, uint hub_num) {
		bytes memory inp = bytes(str_inp);
		uint len = inp.length;
		
		// A very trivial way to check that there are atleast all votes from the hub_num
		// This is almost pointless and should be replaced with signature checks instead
		uint count = 0;
		for(uint k = 0; k< len;k++) if (inp[k] == ',') count += 1;
		if (count != hubs[hub_num].size) throw;
		
		// Iterate through hash string and fill votes in storage
		uint last = 0;
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

	// Same as the below function but throws if the hashes are not from this hub or are not recorded
	// This is done in a separate loop so that the contract takes the entire hubs data or does not take it at all
	function check_hub_hashes(bytes inp, uint hub_num) private {
		uint last = 0;
		uint count = 0;

		for(uint i = 0; i < inp.length; i++) {
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

				if (vote_id[vote_hash] == 0) throw;
				uint voter_num = vote_id[vote_hash] - 1; 
				if (votes[voter_num].hub_num != hub_num) throw;
				last = i+1;
				count += 1;
			}
		}
		if (count != hubs[hub_num].size) throw;

	}

	// Store nonce and choice strings for the votes from hub_num
	function open_hashes(bytes inp, uint hub_num) {
		uint last = 0;
		uint len = inp.length;

		last = 0;

		check_hub_hashes(inp, hub_num);

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

				uint voter_num = vote_id[vote_hash] - 1; 
				votes[voter_num].nonce = vote_nonce;
				random = random^toUint(vote_nonce);
				votes[voter_num].choice = choice;
				last = i+1;
			}
		}	
	}
 
	function remove_invalid_votes() {
		// Send to TRUSTED HARDWARE = PWNAGE!
	}

	// Count votes
	function tally() returns (bytes) {
		if (phase != VotePhase.Open) throw;
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
		phase = VotePhase.Tallied;
		return max_choice;
	}

	// Calculate lottery winner and send cash back
	function end_election() returns (uint hub_num, uint hub_id) {
		if (msg.sender != organizer) throw;
		if (phase != VotePhase.Tallied) throw;
		random = random % num_voters;
		address lottery_winner = voters[voter_addr[random]].repr;
		while(!lottery_winner.send(lottery_pool)) {
			random = (random + 1) % num_voters;
			lottery_winner = voters[voter_addr[random]].repr;
		}
		if(!organizer.send(ether_pool)) throw;
		phase = VotePhase.Terminated;
		return (voters[lottery_winner].hub_num, voters[lottery_winner].hub_id);
		// We do not suicide because the storage will be lost. The organizer can call the die function after storage has been
		// dumped for verifiability.
	}
}