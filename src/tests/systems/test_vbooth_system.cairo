use starkpill::contracts::trait_catalog::{SPillTraitCatalog as TraitCat};
use starkpill::contracts::registry::{SPillSystemRegistry as Registry};
use starkpill::contracts::pill::{
    StarkPill as SPill, IStarkPillDispatcher, IStarkPillDispatcherTrait
};
use starkpill::tests::mocks::eth_mock::{
    EthMock, IERC20MintableDispatcher, IERC20MintableDispatcherTrait
};
use seraphlabs::tokens::erc2114::interface::{ITraitCatalogDispatcher, ITraitCatalogDispatcherTrait};
use souk::systems::interface::{ISoukSystemRegistryDispatcher, ISoukSystemRegistryDispatcherTrait};
use starkpill::systems::mintpill::MintPillSystem;
use starkpill::systems::vbooth::VBoothSystem;
use starkpill::tests::utils;
use starkpill::constants as spill_constants;
use souk::constants as souk_constants;
use seraphlabs::tokens::constants;
use souk::systems::utils::{SystemStatus, SystemStatusTrait};
use seraphlabs::tokens::erc2114::utils::AttrType;
use seraphlabs::utils::testing::{vars, helper};
use starknet::{ContractAddress, ClassHash};
use starknet::testing::{
    set_caller_address, set_contract_address, set_block_timestamp, pop_log, pop_log_raw
};
use debug::PrintTrait;

const BLOCK_TIME_STAMP: u64 = 1698251057;

#[test]
#[available_gas(2000000000)]
fn test_voting_booth() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth
    let tip_price: u256 = 2000000000000000; // 0.002 eth
    let ing_price: u256 = 20000000000000000; // 0.02 eth
    let bg_price: u256 = 120000000000000000; // 0.01 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;
    let name_id = spill_constants::NAME_ID;
    let ing_id = spill_constants::ING_ID;
    let bg_id = spill_constants::BG_ID;
    let mbill_id = spill_constants::MBILL_ID;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to admin
    set_contract_address(admin);
    // set premium to ing and bg
    spill.update_premium(ing_id, 1, ing_price);
    spill.update_premium(bg_id, 1, bg_price);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 3 voting power id 1, 2, 3
    // 18 events
    let spent_eth = pill_base_price + ing_price + bg_price + tip_price;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth);
    spill.execute_system(registry.contract_address, 1, calldata);
    // mint pill with 1 premium ing and 1 premium bg 
    // and scalar remove ing
    // 2 voting power id 4, 5, 6
    // 21 events
    let spent_eth_2 = pill_base_price + ing_price + bg_price;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth_2);
    spill.execute_system(registry.contract_address, 1, calldata);
    spill.scalar_remove_from(4, 5);
    // mint pill with 1 free ing and 1 free bg
    // 1 voting power id 7, 8, 9
    // 16 events
    let calldata = utils::get_mint_pill_calldata(user, 2, 2, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // mint empty pill
    // 1 voting power id 10
    // 4 events
    let calldata = utils::get_mint_pill_calldata(user, 0, 0, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // total voting power 7
    // drop 18 deployment events + 2 Pharmacy premium events + 59 mint events
    //helper::drop_events(spill.contract_address, 79);
    utils::drop_all_events(spill.contract_address);
    assert(spill.attribute_value(10, fame_id) == 0, 'invalid fame val 1');
    assert(spill.attribute_value(10, defame_id) == 0, 'invalid defame val 1');
    // -------------------------------- 1st vote -------------------------------- //
    // fame pill 10  4 times using 2,3,1,6
    let calldata = utils::get_vbooth_calldata(10, 4, true);
    spill.execute_system(registry.contract_address, 2, calldata);
    assert(spill.attribute_value(10, fame_id) == 4, 'invalid fame val 2');
    assert(spill.attribute_value(10, defame_id) == 0, 'invalid defame val 2');

    // -------------------------------- 2nd vote -------------------------------- //
    // defame pill 10  3 times using 4, 7, 10 
    let calldata = utils::get_vbooth_calldata(10, 3, false);
    spill.execute_system(registry.contract_address, 2, calldata);
    assert(spill.attribute_value(10, fame_id) == 4, 'invalid fame val 3');
    assert(spill.attribute_value(10, defame_id) == 3, 'invalid defame val 3');

    // -------------------------------- 3rd vote -------------------------------- //
    // increase time by 1 day
    let new_time_stamp = BLOCK_TIME_STAMP + 86400;
    set_block_timestamp(new_time_stamp);
    // fame pill 10 by 7 using 2,3,1,6,4,7,10
    let calldata = utils::get_vbooth_calldata(10, 7, true);
    spill.execute_system(registry.contract_address, 2, calldata);
    assert(spill.attribute_value(10, fame_id) == 11, 'invalid fame val 4');
    assert(spill.attribute_value(10, defame_id) == 3, 'invalid defame val 4');

    // ------------------------------- test events ------------------------------ //
    // 1st vote
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 1, 2, BLOCK_TIME_STAMP);
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 1, 3, BLOCK_TIME_STAMP);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 1, BLOCK_TIME_STAMP);
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 4, 6, BLOCK_TIME_STAMP);
    utils::assert_pill_vote_event(spill.contract_address, user, 10, true, 4);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 10, fame_id, AttrType::Number(0), 0, 4
    );
    // 2nd vote
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 4, BLOCK_TIME_STAMP);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 7, BLOCK_TIME_STAMP);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 10, BLOCK_TIME_STAMP);
    utils::assert_pill_vote_event(spill.contract_address, user, 10, false, 3);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 10, defame_id, AttrType::Number(0), 0, 3
    );
    // 3rd vote
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 1, 2, new_time_stamp);
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 1, 3, new_time_stamp);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 1, new_time_stamp);
    utils::assert_trait_vote_time_stamp_event(spill.contract_address, 4, 6, new_time_stamp);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 4, new_time_stamp);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 7, new_time_stamp);
    utils::assert_pill_vote_time_stamp_event(spill.contract_address, 10, new_time_stamp);
    utils::assert_pill_vote_event(spill.contract_address, user, 10, true, 7);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 10, fame_id, AttrType::Number(0), 4, 11
    );
    helper::assert_no_events_left(spill.contract_address);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: not enough voting power', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_not_enough_votes() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth
    let tip_price: u256 = 2000000000000000; // 0.002 eth
    let ing_price: u256 = 20000000000000000; // 0.02 eth
    let bg_price: u256 = 120000000000000000; // 0.01 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;
    let name_id = spill_constants::NAME_ID;
    let ing_id = spill_constants::ING_ID;
    let bg_id = spill_constants::BG_ID;
    let mbill_id = spill_constants::MBILL_ID;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to admin
    set_contract_address(admin);
    // set premium to ing and bg
    spill.update_premium(ing_id, 1, ing_price);
    spill.update_premium(bg_id, 1, bg_price);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // amd remove all inventory 
    // 1 voting power id 1, 2, 3
    let spent_eth = pill_base_price + ing_price + bg_price + tip_price;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth);
    spill.execute_system(registry.contract_address, 1, calldata);
    spill.scalar_remove_from(1, 2);
    spill.scalar_remove_from(1, 3);
    // vote with pill once 
    let calldata = utils::get_vbooth_calldata(1, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
    // transfer back in traits and try to vote again to ensure 
    // pill is voting conduit
    spill.scalar_transfer_from(user, 2, 1);
    spill.scalar_transfer_from(user, 3, 1);
    let calldata = utils::get_vbooth_calldata(1, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: cant vote on non pill', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_vote_on_non_pill() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 1 voting power id 1, 2, 3
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // vote on ing
    let calldata = utils::get_vbooth_calldata(2, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: invalid token_id', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_vote_on_invalid_token_id() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 1 voting power id 1, 2, 3
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // vote with pill once 
    let calldata = utils::get_vbooth_calldata(0, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: invalid vote ammount', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_zero_vote() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 1 voting power id 1, 2, 3
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // vote with pill once 
    let calldata = utils::get_vbooth_calldata(1, 0, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_invalid_caller() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 1 voting power id 1, 2, 3
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // set address to invalid adress
    set_contract_address(vars::INVALID_ADDRESS());
    // vote with pill once 
    let calldata = utils::get_vbooth_calldata(1, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: cant call self', 'ENTRYPOINT_FAILED'))]
fn test_voting_booth_caller_is_contract() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let ten_eth: u256 = 10000000000000000000; // 1 eth

    let pill_base_price = spill_constants::PILL_BASE_PRICE;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;
    // set timestamp
    set_block_timestamp(BLOCK_TIME_STAMP);

    // set caller to user
    set_contract_address(user);
    // mint eth to user
    eth.mint(user, ten_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, ten_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    // 1 voting power id 1, 2, 3
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // set address to spill contract
    set_contract_address(spill.contract_address);
    // vote with pill once 
    let calldata = utils::get_vbooth_calldata(1, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
}
