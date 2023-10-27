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

#[test]
#[available_gas(2000000000)]
fn test_pharmacy() {
    // deploy eth mock
    let eth_addr = utils::setup_eth();
    // deploy trait catalog
    let trait_cat_addr = utils::setup_trait_catalog();
    // deploy system registry
    let registry_addr = utils::setup_system_registry();
    // deploy starkpill
    let starkpill_addr = utils::setup_starkpill(eth_addr, trait_cat_addr, registry_addr);
    // return dispatcher
    let spill = IStarkPillDispatcher { contract_address: starkpill_addr };
    // drop deployment events
    helper::drop_events(starkpill_addr, 18);

    let admin = vars::ADMIN();
    let owner = vars::OWNER();
    let zero_addr = vars::INVALID_ADDRESS();

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

    // -------------------------- initializer assetions ------------------------- //
    assert(spill.get_eth_premium(name_id, 1) == pill_base_price, 'wrong pill premium');
    assert(spill.get_pharmacy_addresses(true, 0) == eth_addr, 'wrong eth address');
    assert(spill.get_pharmacy_addresses(false, 0) == owner, 'wrong wallet address');

    assert(spill.get_eth_premium(ing_id, 1) == 0, 'wrong premium 1');
    assert(spill.get_stock(ing_id, 1) == (0, 0), 'wrong stock 1');
    // set caller to admin
    set_contract_address(admin);

    spill.update_premium(ing_id, 1, 1000);
    assert(spill.get_eth_premium(ing_id, 1) == 1000, 'wrong premium 2');
    spill.update_premium(ing_id, 1, 500);
    assert(spill.get_eth_premium(ing_id, 1) == 500, 'wrong premium 3');
    // add stock
    spill.update_stock(ing_id, 1, 200);
    assert(spill.get_stock(ing_id, 1) == (0, 200), 'wrong stock 2');
    spill.update_stock(ing_id, 1, 100);
    assert(spill.get_stock(ing_id, 1) == (0, 300), 'wrong stock 3');
    // clear stock
    spill.update_stock(ing_id, 1, 0);
    assert(spill.get_stock(ing_id, 1) == (0, 0), 'wrong stock 4');
    // check l2 redemption approval
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 1) == false, 'wrong approval 1');
    spill.set_l2_project_redemtion(zero_addr, ing_id, array![1, 2, 3, 4].span(), true);
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 1) == true, 'wrong approval 2');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 2) == true, 'wrong approval 3');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 3) == true, 'wrong approval 4');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 4) == true, 'wrong approval 5');
    // clear approval
    spill.set_l2_project_redemtion(zero_addr, ing_id, array![1, 3].span(), false);
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 1) == false, 'wrong approval 6');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 2) == true, 'wrong approval 7');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 3) == false, 'wrong approval 8');
    assert(spill.l2_reedemtion_approval(zero_addr, ing_id, 4) == true, 'wrong approval 9');
    // test events
    utils::assert_pharmacy_premium_event(starkpill_addr, ing_id, 1, eth_addr, 1000);
    utils::assert_pharmacy_premium_event(starkpill_addr, ing_id, 1, eth_addr, 500);
    utils::assert_pharmacy_stock_update_event(starkpill_addr, ing_id, 1, 0, 200);
    utils::assert_pharmacy_stock_update_event(starkpill_addr, ing_id, 1, 0, 300);
    utils::assert_pharmacy_stock_update_event(starkpill_addr, ing_id, 1, 0, 0);
    utils::assert_pharmacy_l2_redemption_approval_event(starkpill_addr, zero_addr, ing_id, 1, true);
    utils::assert_pharmacy_l2_redemption_approval_event(starkpill_addr, zero_addr, ing_id, 2, true);
    utils::assert_pharmacy_l2_redemption_approval_event(starkpill_addr, zero_addr, ing_id, 3, true);
    utils::assert_pharmacy_l2_redemption_approval_event(starkpill_addr, zero_addr, ing_id, 4, true);
    utils::assert_pharmacy_l2_redemption_approval_event(
        starkpill_addr, zero_addr, ing_id, 1, false
    );
    utils::assert_pharmacy_l2_redemption_approval_event(
        starkpill_addr, zero_addr, ing_id, 3, false
    );
    helper::assert_no_events_left(starkpill_addr);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_non_admin_update_premium() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let operator = vars::OPERATOR();

    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(operator);

    spill.update_premium(ing_id, 1, 1000);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_non_admin_update_stock() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let operator = vars::OPERATOR();
    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(operator);

    spill.update_stock(ing_id, 1, 1000);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: stock already set', 'ENTRYPOINT_FAILED'))]
fn test_update_already_set_stock() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(admin);

    spill.update_stock(ing_id, 1, 0);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_non_admin_l2_redeem_approval() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let operator = vars::OPERATOR();
    let zero_addr = vars::INVALID_ADDRESS();

    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(operator);

    spill.set_l2_project_redemtion(zero_addr, ing_id, array![1, 2, 3, 4].span(), true);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: invalid trait index', 'ENTRYPOINT_FAILED'))]
fn test_zero_attr_id_l2_redeem_approval() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let zero_addr = vars::INVALID_ADDRESS();

    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(admin);

    spill.set_l2_project_redemtion(zero_addr, ing_id, array![0].span(), true);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('SPill: redeemable already set', 'ENTRYPOINT_FAILED'))]
fn test_repeat_l2_redeem_approval() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let zero_addr = vars::INVALID_ADDRESS();

    let ing_id = spill_constants::ING_ID;
    // set caller to admin
    set_contract_address(admin);

    spill.set_l2_project_redemtion(zero_addr, ing_id, array![1, 2, 3].span(), false);
}
