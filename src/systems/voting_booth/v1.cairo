#[starknet::contract]
mod VBoothSystem {
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address, get_contract_address, get_block_timestamp};
    use souk::systems::interface;
    use seraphlabs::tokens::erc2114::utils::{AttrType, AttrTypeTrait};
    use seraphlabs::tokens::constants;
    use starkpill::constants as pill_constants;
    // token components
    use seraphlabs::tokens::erc721::{ERC721Component, extensions::ERC721EnumComponent};
    use seraphlabs::tokens::erc3525::ERC3525Component;
    use seraphlabs::tokens::erc2114::{ERC2114Component, extensions::ERC2114InvComponent};
    use ERC721Component::ERC721InternalImpl;
    use ERC721EnumComponent::ERC721EnumInternalImpl;
    use ERC3525Component::IERC3525Impl;
    use ERC2114Component::{IERC2114Impl, ERC2114InternalImpl, ERC2114PrivateImpl};
    use ERC2114InvComponent::{ERC2114InvInternalImpl, ERC2114InvPrivateImpl};

    // pharmacy
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721EnumComponent, storage: erc721_enum, event: ERC721EnumEvent);
    component!(path: ERC3525Component, storage: erc3525, event: ERC3525Event);
    component!(path: ERC2114Component, storage: erc2114, event: ERC2114Event);
    component!(path: ERC2114InvComponent, storage: erc2114_inv, event: ERC2114InvEvent);

    #[storage]
    struct Storage {
        spill_vbooth_token_last_vote: LegacyMap<u256, u64>,
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enum: ERC721EnumComponent::Storage,
        #[substorage(v0)]
        erc3525: ERC3525Component::Storage,
        #[substorage(v0)]
        erc2114: ERC2114Component::Storage,
        #[substorage(v0)]
        erc2114_inv: ERC2114InvComponent::Storage,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        PillVote: PillVote,
        PillVoteTimeStamp: PillVoteTimeStamp,
        TraitVoteTimeStamp: TraitVoteTimeStamp,
        ERC721Event: ERC721Component::Event,
        ERC721EnumEvent: ERC721EnumComponent::Event,
        ERC3525Event: ERC3525Component::Event,
        ERC2114Event: ERC2114Component::Event,
        ERC2114InvEvent: ERC2114InvComponent::Event,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PillVote {
        #[key]
        voter: ContractAddress,
        #[key]
        token_id: u256,
        #[key]
        vote: bool,
        ammount: felt252
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PillVoteTimeStamp {
        #[key]
        token_id: u256,
        time_stamp: u64
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct TraitVoteTimeStamp {
        #[key]
        pill_id: u256,
        #[key]
        token_id: u256,
        time_stamp: u64
    }


    #[external(v0)]
    impl VBoothSystemImpl of interface::ISoukSystem<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            'Spill Vbooth V1'
        }

        fn author(self: @ContractState) -> felt252 {
            'kahi'
        }

        fn required_interfaces(self: @ContractState) -> Span<felt252> {
            array![
                constants::IERC721_ID,
                constants::IERC721_ENUMERABLE_ID,
                constants::IERC3525_ID,
                constants::IERC2114_ID,
                constants::IERC2114_INVENTORY_ID,
            ]
                .span()
        }

        fn system_uri(self: @ContractState) -> Array<felt252> {
            array!['starkpill voting booth']
        }
    }

    #[generate_trait]
    #[external(v0)]
    impl VBoothSystemExecutableIImpl of VBoothSystemExecutableTrait {
        fn initializer(ref self: ContractState) {}
        // @dev fame or defame a token
        // uses caller pills to vote
        // token_id must be a pill and must exist
        // `vote` determines whether it is a fame or defame
        //  EMITS x ammount of TraitVoteTimeStamp events
        //  EMITS x ammount of PillVoteTimeStamp events
        //  EMITS 1 PillVote event
        //  EMITS 1 TokenAttributeUpdate event
        fn execute(ref self: ContractState, token_id: u256, ammount: felt252, vote: bool) {
            // assert caller is not zero
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'Spill: invalid caller');
            // assert caller is not spill address
            let spill_contract = get_contract_address();
            assert(caller != spill_contract, 'Spill: cant call self');
            // assert token_id is exist
            assert(self.erc721._exist(token_id), 'Spill: invalid token id');
            // assert token_id is a pill
            assert(
                self.erc3525.slot_of(token_id) == pill_constants::PILL_SLOT,
                'Spill: cant vote on non pill'
            );
            // assert ammount is not zero
            assert(ammount.is_non_zero(), 'Spill: invalid vote ammount');
            // ---------------------------- use voting power ---------------------------- //
            let cur_time_stamp = get_block_timestamp();
            let mut votes_left = ammount;
            // loop throuh callers owned tokens to try and execute votes
            let mut index: u256 = 0;
            loop {
                match self.erc721_enum._token_of_owner_by_index(caller, index) {
                    Option::Some(owned_id) => {
                        // if no more votes left break
                        if votes_left.is_zero() {
                            break;
                        }
                        // try and execute vote with token if cant will do nothing
                        // EMITS 0-2 TraitVoteTimeStamp events 
                        // EMITS 0-1 PillVoteTimeStamp events
                        self._execute_votes_with_pill(owned_id, cur_time_stamp, ref votes_left);
                        index += 1;
                    },
                    Option::None(_) => { break; }
                };
            };

            // assert that there are no votes_left
            // if there are votes left that means that the caller does not have enough voting power
            assert(votes_left.is_zero(), 'Spill: not enough voting power');

            // ------------------------- add attributes to token ------------------------ //
            // @dev EMITS 1 TokenAttributeUpdate event
            // if vote is true append fame attribute else append defame attribute
            let mut attr_ids = ArrayTrait::<u64>::new();
            match vote {
                bool::False => attr_ids.append(pill_constants::DEFAME_ID),
                bool::True => attr_ids.append(pill_constants::FAME_ID),
            };

            // emit event
            self.emit(PillVote { voter: caller, token_id, vote, ammount });

            self
                .erc2114
                ._add_attributes_to_token(token_id, attr_ids.span(), array![ammount].span());
        }
    }

    #[generate_trait]
    impl VBoothSystemInternalImpl of VBoothSystemInternalTrait {
        // @dev trys and execute votes with pill
        //  if pill is the conduit for votes so if it cant vote then it cant use its trait to vote
        //  voting uses traits first if they are a premium trait and has not vote in the last 24 hours
        //  EMITS 0-2 TraitVoteTimeStamp events 
        //  EMITS 0-1 PillVoteTimeStamp events
        fn _execute_votes_with_pill(
            ref self: ContractState, token_id: u256, time_stamp: u64, ref votes_left: felt252
        ) {
            // if pill cant vote return
            if !self._can_pill_vote(token_id, time_stamp) {
                return;
            }

            // --------------------- execute votes with traits first -------------------- //
            // get pills inventory
            let mut pill_inv = self.erc2114_inv._inventory_of(token_id).span();
            // loop through pills inventory to see if we use it to vote
            loop {
                match pill_inv.pop_front() {
                    Option::Some(child_id) => {
                        // if no more votes left break
                        if votes_left.is_zero() {
                            break;
                        }
                        // try and execute vote with trait if cant will do nothing
                        // EMITS TraitVoteTimeStamp event
                        self
                            ._try_and_execute_vote_with_trait(
                                token_id, *child_id, time_stamp, ref votes_left
                            );
                    },
                    Option::None(_) => { break; }
                };
            };

            // if no more votes return
            if votes_left.is_zero() {
                return;
            }

            // ------------------------- execute vote with pill ------------------------- //
            // reduce votes left by 1     
            votes_left -= 1;
            // set time_stamp on pill
            self.spill_vbooth_token_last_vote.write(token_id, time_stamp);
            // emit event
            self.emit(PillVoteTimeStamp { token_id, time_stamp });
        }

        // @dev checks if trait can vote and adds time stamp to token
        //  DOES NOT check if tokenid is a trait
        //  DOES NOT check if there is enough votes left
        //  DOES NOT check if pill_id and token_id are valid
        //  DOES NOT check if pill_id is parent of token_id
        //  EMITS TraitVoteTimeStamp event
        #[inline(always)]
        fn _try_and_execute_vote_with_trait(
            ref self: ContractState,
            pill_id: u256,
            token_id: u256,
            time_stamp: u64,
            ref votes_left: felt252
        ) {
            // if trait canT vote return
            if !self._can_trait_vote(token_id, time_stamp) {
                return;
            }
            // reduce votes left by 1 
            votes_left -= 1;
            // set time_stamp on token
            self.spill_vbooth_token_last_vote.write(token_id, time_stamp);
            // emit event
            self.emit(TraitVoteTimeStamp { pill_id, token_id, time_stamp });
        }
    }

    #[generate_trait]
    impl VBoothSystemPrivateImpl of VBoothSystemPrivateTrait {
        #[inline(always)]
        fn _can_pill_vote(self: @ContractState, token_id: u256, time_stamp: u64) -> bool {
            // check if token_id is pill if its not return as it cant execute votes
            match self.erc3525.slot_of(token_id) == pill_constants::PILL_SLOT {
                bool::False => { false },
                bool::True => {
                    // check if token_id has not voted in the last 24 hours
                    // only return true if last vote is zero or last vote is more than 24 hours ago
                    let last_vote = self.spill_vbooth_token_last_vote.read(token_id);
                    last_vote.is_zero() || pill_constants::VOTE_COOLDOWN <= (time_stamp - last_vote)
                }
            }
        }

        // @dev assumes `token_id` is a trait
        #[inline(always)]
        fn _can_trait_vote(self: @ContractState, token_id: u256, time_stamp: u64) -> bool {
            let mbill_attr = pill_constants::MBILL_ID;
            // check if trait is premium trait
            // if token_id is does not have mbill attribute return false
            // else check if token_id has not voted in the last 24 hours 
            match self.erc2114.attribute_value(token_id, mbill_attr).is_non_zero() {
                bool::False => { false },
                bool::True => {
                    // check if token_id has not voted in the last 24 hours
                    // only return true if last vote is zero or last vote is more than 24 hours ago
                    let last_vote = self.spill_vbooth_token_last_vote.read(token_id);
                    last_vote.is_zero() || pill_constants::VOTE_COOLDOWN <= (time_stamp - last_vote)
                }
            }
        }
    }
}
