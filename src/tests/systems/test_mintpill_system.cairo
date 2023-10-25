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
use starknet::testing::{set_caller_address, set_contract_address, pop_log, pop_log_raw};
use debug::PrintTrait;

fn HELLO() {}

#[test]
#[available_gas(2000000000)]
fn test_mint_pill() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth
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

    // set caller to admin
    set_contract_address(admin);
    // set premium to ing and bg
    spill.update_premium(ing_id, 1, ing_price);
    spill.update_premium(bg_id, 1, bg_price);

    // drop deployment events + 2 Pharmacy premium events
    helper::drop_events(spill.contract_address, 20);

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    assert(eth.balance_of(operator) == one_eth, 'wrong eth balance 1');
    assert(eth.balance_of(wallet) == 0, 'wrong eth balance 2');
    assert(spill.total_supply() == 0, 'wrong total supply 1');

    // mint pill with 1 premium ing and 1 premium bg + tips
    let spent_eth = pill_base_price + ing_price + bg_price + tip_price;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth);
    spill.execute_system(registry.contract_address, 1, calldata);
    // mint pill with 1 free ing and 1 free bg
    let calldata = utils::get_mint_pill_calldata(user, 2, 2, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);

    // ----------------------------- check balances ----------------------------- //
    let remaining_eth = one_eth - spent_eth - pill_base_price;
    assert(eth.balance_of(operator) == remaining_eth, 'wrong eth balance 3');
    assert(eth.balance_of(wallet) == spent_eth + pill_base_price, 'wrong eth balance 4');
    assert(spill.total_supply() == 6, 'wrong total supply 2');
    assert(spill.token_balance_of(1) == 2, 'wrong token bal 1');
    assert(spill.token_balance_of(4) == 2, 'wrong token bal 2');

    // ------------------------------ check slot of ----------------------------- //
    assert(spill.slot_of(1) == pill_slot, 'wrong slot of 1');
    assert(spill.slot_of(2) == ing_slot, 'wrong slot of 2');
    assert(spill.slot_of(3) == bg_slot, 'wrong slot of 3');
    assert(spill.slot_of(4) == pill_slot, 'wrong slot of 4');
    assert(spill.slot_of(5) == ing_slot, 'wrong slot of 5');
    assert(spill.slot_of(6) == bg_slot, 'wrong slot of 6');

    // ------------------------------- check owner ------------------------------ //
    assert(spill.owner_of(1) == user, 'wrong owner 1');
    assert(spill.owner_of(2) == spill.contract_address, 'wrong owner 2');
    assert(spill.owner_of(3) == spill.contract_address, 'wrong owner 3');
    assert(spill.owner_of(4) == user, 'wrong owner 4');
    assert(spill.owner_of(5) == spill.contract_address, 'wrong owner 5');
    assert(spill.owner_of(6) == spill.contract_address, 'wrong owner 6');

    // ----------------------------- check inventory ---------------------------- //
    assert(spill.token_of(1) == 0, 'wrong token of 1');
    assert(spill.token_of(2) == 1, 'wrong token of 2');
    assert(spill.token_of(3) == 1, 'wrong token of 3');
    assert(spill.token_of(4) == 0, 'wrong token of 4');
    assert(spill.token_of(5) == 4, 'wrong token of 5');
    assert(spill.token_of(6) == 4, 'wrong token of 6');
    assert(spill.token_supply_in_inventory(1, ing_slot) == 1, 'wrong inv supply 1');
    assert(spill.token_supply_in_inventory(1, bg_slot) == 1, 'wrong inv supply 2');
    assert(spill.inventory_of(1) == array![2, 3].span(), 'wrong inv 1');
    assert(spill.token_supply_in_inventory(4, ing_slot) == 1, 'wrong inv supply 3');
    assert(spill.token_supply_in_inventory(4, bg_slot) == 1, 'wrong inv supply 4');
    assert(spill.inventory_of(4) == array![5, 6].span(), 'wrong inv 2');

    // -------------------------- check token indexing -------------------------- //
    assert(spill.token_of_token_by_index(1, 0) == 2, 'wrong token index 1');
    assert(spill.token_of_token_by_index(1, 1) == 3, 'wrong token index 2');
    assert(spill.token_of_token_by_index(4, 0) == 5, 'wrong token index 3');
    assert(spill.token_of_token_by_index(4, 1) == 6, 'wrong token index 4');

    assert(spill.token_of_owner_by_index(user, 0) == 1, 'wrong owner index 1');
    assert(spill.token_of_owner_by_index(user, 1) == 4, 'wrong owner index 2');
    assert(spill.token_of_owner_by_index(spill.contract_address, 0) == 2, 'wrong owner index 3');
    assert(spill.token_of_owner_by_index(spill.contract_address, 1) == 3, 'wrong owner index 4');
    assert(spill.token_of_owner_by_index(spill.contract_address, 2) == 5, 'wrong owner index 5');
    assert(spill.token_of_owner_by_index(spill.contract_address, 3) == 6, 'wrong owner index 6');

    // ------------------------ check attribute values of ----------------------- //
    assert(spill.attributes_of(1) == array![mbill_id].span(), 'wrong attr of 1');
    assert(spill.attributes_of(2) == array![ing_id, mbill_id].span(), 'wrong attr of 2');
    assert(spill.attributes_of(3) == array![bg_id, mbill_id].span(), 'wrong attr of 3');
    assert(spill.attributes_of(4) == array![mbill_id].span(), 'wrong attr of 4');
    assert(spill.attributes_of(5) == array![ing_id].span(), 'wrong attr of 5');
    assert(spill.attributes_of(6) == array![bg_id].span(), 'wrong attr of 6');

    // ------------------------- check attributes values ------------------------ //
    assert(
        spill.attribute_value(1, mbill_id) == (pill_base_price + tip_price).try_into().unwrap(),
        'wrong attr val 1'
    );
    assert(spill.attribute_value(2, ing_id) == 'Cairo Cap', 'wrong attr val 2');
    assert(spill.attribute_value(2, mbill_id) == ing_price.try_into().unwrap(), 'wrong attr val 3');
    assert(spill.attribute_value(3, bg_id) == 'Yellow', 'wrong attr val 4');
    assert(spill.attribute_value(3, mbill_id) == bg_price.try_into().unwrap(), 'wrong attr val 5');
    assert(
        spill.attribute_value(4, mbill_id) == pill_base_price.try_into().unwrap(),
        'wrong attr val 6'
    );
    assert(spill.attribute_value(5, ing_id) == 'Pepe', 'wrong attr val 7');
    assert(spill.attribute_value(5, mbill_id) == 0, 'wrong attr val 8');
    assert(spill.attribute_value(6, bg_id) == 'Rocket', 'wrong attr val 9');
    assert(spill.attribute_value(6, mbill_id) == 0, 'wrong attr val 10');

    // ------------------------ equipped attribute values ----------------------- //
    assert(
        spill.equipped_attribute_value(1, mbill_id) == spent_eth.try_into().unwrap(),
        'wrong eq attr val 1'
    );
    assert(spill.equipped_attribute_value(1, ing_id) == 'Cairo Cap', 'wrong eq attr val 2');
    assert(spill.equipped_attribute_value(1, bg_id) == 'Yellow', 'wrong eq attr val 3');
    assert(
        spill.equipped_attribute_value(4, mbill_id) == pill_base_price.try_into().unwrap(),
        'wrong eq attr val 4'
    );
    assert(spill.equipped_attribute_value(4, ing_id) == 'Pepe', 'wrong eq attr val 5');
    assert(spill.equipped_attribute_value(4, bg_id) == 'Rocket', 'wrong eq attr val 6');

    // ------------------------------- test events ------------------------------ //
    // mint 1st pill
    utils::assert_transfer_event(spill.contract_address, Zeroable::zero(), user, 1);
    utils::assert_slot_changed_event(spill.contract_address, 1, 0, pill_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 1, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address,
        1,
        mbill_id,
        AttrType::Number(0),
        0,
        (pill_base_price + tip_price).try_into().unwrap()
    );
    // mint 1st ing
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 2
    );
    utils::assert_slot_changed_event(spill.contract_address, 2, 0, ing_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 2, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 2, ing_id, AttrType::String(2), 0, 1
    );
    utils::assert_token_attribute_update_event(
        spill.contract_address, 2, mbill_id, AttrType::Number(0), 0, ing_price.try_into().unwrap()
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 2, 1, false);
    utils::assert_inventory_updated_event(spill.contract_address, 1, ing_slot, 2, 0, 1);
    // mint 1st bg
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 3
    );
    utils::assert_slot_changed_event(spill.contract_address, 3, 0, bg_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 3, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 3, bg_id, AttrType::String(3), 0, 1
    );
    utils::assert_token_attribute_update_event(
        spill.contract_address, 3, mbill_id, AttrType::Number(0), 0, bg_price.try_into().unwrap()
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 3, 1, false);
    utils::assert_inventory_updated_event(spill.contract_address, 1, bg_slot, 3, 0, 1);
    // mint 2nd pill
    utils::assert_transfer_event(spill.contract_address, Zeroable::zero(), user, 4);
    utils::assert_slot_changed_event(spill.contract_address, 4, 0, pill_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 4, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address,
        4,
        mbill_id,
        AttrType::Number(0),
        0,
        pill_base_price.try_into().unwrap()
    );
    // mint 2nd ing
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 5
    );
    utils::assert_slot_changed_event(spill.contract_address, 5, 0, ing_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 5, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 5, ing_id, AttrType::String(2), 0, 2
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 5, 4, false);
    utils::assert_inventory_updated_event(spill.contract_address, 4, ing_slot, 5, 0, 1);
    // mint 1st bg
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 6
    );
    utils::assert_slot_changed_event(spill.contract_address, 6, 0, bg_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 6, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 6, bg_id, AttrType::String(3), 0, 2
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 6, 4, false);
    utils::assert_inventory_updated_event(spill.contract_address, 4, bg_slot, 6, 0, 1);
    helper::assert_no_events_left(spill.contract_address);
}

#[test]
#[available_gas(2000000000)]
fn test_mint_pill_clear_stock() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth
    let ing_stock = 20;
    let bg_stock = 10;

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

    // set caller to admin
    set_contract_address(admin);
    // set stock for ing and bg
    spill.update_stock(ing_id, 2, ing_stock);
    spill.update_stock(bg_id, 2, bg_stock);

    // drop deployment events + 2 PharmacyStockUpdate events
    helper::drop_events(spill.contract_address, 20);

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    assert(spill.get_stock(ing_id, 2) == (0, ing_stock), 'wrong stock 1');
    assert(spill.get_stock(bg_id, 2) == (0, bg_stock), 'wrong stock 2');
    // mint pill with 1 free ing 
    let calldata = utils::get_mint_pill_calldata(user, 2, 0, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // mint pill with 1 free bg
    let calldata = utils::get_mint_pill_calldata(user, 0, 2, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);

    // ------------------------------- check stock ------------------------------ //
    assert(spill.get_stock(ing_id, 2) == (1, ing_stock), 'wrong stock 3');
    assert(spill.get_stock(bg_id, 2) == (1, bg_stock), 'wrong stock 4');

    // ------------------------------ check supply ------------------------------ //
    assert(spill.total_supply() == 4, 'wrong total supply 1');
    assert(spill.inventory_of(1) == array![2].span(), 'wrong inv 1');
    assert(spill.inventory_of(3) == array![4].span(), 'wrong inv 2');

    // --------------------- check equipped attribute value --------------------- //
    assert(
        spill.equipped_attribute_value(1, mbill_id) == pill_base_price.try_into().unwrap(),
        'wrong eq attr val 1'
    );
    assert(spill.equipped_attribute_value(1, ing_id) == 'Pepe', 'wrong eq attr val 2');
    assert(spill.equipped_attribute_value(1, bg_id) == 0, 'wrong eq attr val 3');
    assert(
        spill.equipped_attribute_value(3, mbill_id) == pill_base_price.try_into().unwrap(),
        'wrong eq attr val 4'
    );
    assert(spill.equipped_attribute_value(3, ing_id) == 0, 'wrong eq attr val 5');
    assert(spill.equipped_attribute_value(3, bg_id) == 'Rocket', 'wrong eq attr val 6');

    // ------------------------------- test events ------------------------------ //
    // mint 1st pill
    utils::assert_transfer_event(spill.contract_address, Zeroable::zero(), user, 1);
    utils::assert_slot_changed_event(spill.contract_address, 1, 0, pill_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 1, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address,
        1,
        mbill_id,
        AttrType::Number(0),
        0,
        pill_base_price.try_into().unwrap()
    );
    // mint 1st ing
    utils::assert_pharmacy_stock_update_event(spill.contract_address, ing_id, 2, 1, ing_stock);
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 2
    );
    utils::assert_slot_changed_event(spill.contract_address, 2, 0, ing_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 2, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 2, ing_id, AttrType::String(2), 0, 2
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 2, 1, false);
    utils::assert_inventory_updated_event(spill.contract_address, 1, ing_slot, 2, 0, 1);
    // mint 2nd pill
    utils::assert_transfer_event(spill.contract_address, Zeroable::zero(), user, 3);
    utils::assert_slot_changed_event(spill.contract_address, 3, 0, pill_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 3, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address,
        3,
        mbill_id,
        AttrType::Number(0),
        0,
        pill_base_price.try_into().unwrap()
    );
    // mint 1st bg
    utils::assert_pharmacy_stock_update_event(spill.contract_address, bg_id, 2, 1, bg_stock);
    utils::assert_transfer_event(
        spill.contract_address, Zeroable::zero(), spill.contract_address, 4
    );
    utils::assert_slot_changed_event(spill.contract_address, 4, 0, bg_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 4, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address, 4, bg_id, AttrType::String(3), 0, 2
    );
    utils::assert_scalar_transfer_event(spill.contract_address, user, 4, 3, false);
    utils::assert_inventory_updated_event(spill.contract_address, 3, bg_slot, 4, 0, 1);
    helper::assert_no_events_left(spill.contract_address);
}

#[test]
#[available_gas(2000000000)]
fn test_mint_empty_pill() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth

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

    // drop deployment events 
    helper::drop_events(spill.contract_address, 18);

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    let calldata = utils::get_mint_pill_calldata(user, 0, 0, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);

    // ------------------------------ check supply ------------------------------ //
    assert(spill.total_supply() == 1, 'wrong total supply 1');
    assert(spill.inventory_of(1) == array![].span(), 'wrong inv 1');

    // --------------------- check equipped attribute value --------------------- //
    assert(
        spill.equipped_attribute_value(1, mbill_id) == pill_base_price.try_into().unwrap(),
        'wrong eq attr val 1'
    );
    assert(spill.equipped_attribute_value(1, ing_id) == 0, 'wrong eq attr val 2');
    assert(spill.equipped_attribute_value(1, bg_id) == 0, 'wrong eq attr val 3');

    // ------------------------------- test events ------------------------------ //
    // mint 1st pill
    utils::assert_transfer_event(spill.contract_address, Zeroable::zero(), user, 1);
    utils::assert_slot_changed_event(spill.contract_address, 1, 0, pill_slot);
    utils::assert_transfer_value_event(spill.contract_address, 0, 1, 0);
    utils::assert_token_attribute_update_event(
        spill.contract_address,
        1,
        mbill_id,
        AttrType::Number(0),
        0,
        pill_base_price.try_into().unwrap()
    );
    helper::assert_no_events_left(spill.contract_address);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('ERC2114: invalid attr_id value', 'ENTRYPOINT_FAILED'))]
fn test_invalid_attr_id_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth

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

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    let calldata = utils::get_mint_pill_calldata(user, 10, 0, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: minimum price not met', 'ENTRYPOINT_FAILED'))]
fn test_invalid_price_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth
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

    // set caller to admin
    set_contract_address(admin);
    // set premium to ing and bg
    spill.update_premium(ing_id, 1, ing_price);
    spill.update_premium(bg_id, 1, bg_price);

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    let invalid_eth = pill_base_price + ing_price + bg_price - 1;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, invalid_eth);
    spill.execute_system(registry.contract_address, 1, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: not enough eth', 'ENTRYPOINT_FAILED'))]
fn test_invalid_eth_balance_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth
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

    // set caller to admin
    set_contract_address(admin);
    // set premium to ing and bg
    spill.update_premium(ing_id, 1, ing_price);
    spill.update_premium(bg_id, 1, bg_price);

    let spent_eth = pill_base_price + ing_price + bg_price;
    let invalid_eth = spent_eth - 1;
    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, invalid_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth);
    spill.execute_system(registry.contract_address, 1, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: only redemption', 'ENTRYPOINT_FAILED'))]
fn test_redemption_only_attr_id_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth

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

    // set bg_id 1 to redemption only
    set_contract_address(admin);
    spill.set_l2_project_redemtion(Zeroable::zero(), bg_id, array![1].span(), true);

    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: no stock', 'ENTRYPOINT_FAILED'))]
fn test_no_stock_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth

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

    // add 1 stock to ing and bg 
    set_contract_address(admin);
    spill.update_stock(ing_id, 1, 1);
    // set caller to operator
    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);
    // mint first to clear stock
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
    // mint twice to try and sell stock 
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: invalid caller', 'ENTRYPOINT_FAILED'))]
fn test_invalid_caller_mint() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();
    let user = vars::USER();
    let wallet = vars::OWNER();

    let one_eth: u256 = 1000000000000000000; // 1 eth

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

    set_contract_address(operator);
    // mint eth to operator
    eth.mint(operator, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);
    set_contract_address(vars::INVALID_ADDRESS());

    let calldata = utils::get_mint_pill_calldata(user, 1, 1, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);
}
