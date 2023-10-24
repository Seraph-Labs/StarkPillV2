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
fn test_assert_admin() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;

    set_contract_address(admin);
    spill.set_slot_criteria(ing_slot, bg_slot, 10);
    assert(spill.slot_criteria_capacity(ing_slot, bg_slot) == 10, 'admin role fail');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller not admin', 'ENTRYPOINT_FAILED'))]
fn test_invalid_admin_call() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;

    set_contract_address(operator);
    spill.set_slot_criteria(ing_slot, bg_slot, 10);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Invalid Caller', 'ENTRYPOINT_FAILED'))]
fn test_zero_caller() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;

    set_contract_address(vars::INVALID_ADDRESS());
    spill.set_slot_criteria(ing_slot, bg_slot, 10);
}
