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
fn test_access() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    // ------------------------------- check access ------------------------------ //
    assert(spill.has_role(default_admin_role, admin), 'default role not set');
    assert(spill.has_role(admin_role, admin), 'admin role not set');
    assert(spill.get_role_admin(admin_role) == default_admin_role, 'role admin not set');

    // set admin as caller
    set_contract_address(admin);
    spill.grant_role(default_admin_role, operator);
    spill.grant_role(admin_role, operator);
    assert(spill.has_role(default_admin_role, operator), 'default role not granted');
    assert(spill.has_role(admin_role, operator), 'admin role not granted');

    // revoke role 
    spill.revoke_role(default_admin_role, operator);
    assert(!spill.has_role(default_admin_role, operator), 'default role not revoked');
    // renounce role
    set_contract_address(operator);
    spill.renounce_role(admin_role, operator);
    assert(!spill.has_role(admin_role, operator), 'admin role not renounced');
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_unauthroized_grant_default_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    // set admin as caller
    set_contract_address(operator);
    spill.grant_role(default_admin_role, operator);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_unauthroized_grant_admin_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let admin_role = spill_constants::ADMIN_ROLE;
    // set admin as caller
    set_contract_address(operator);
    spill.grant_role(admin_role, operator);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_unauthorized_revoke_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    set_contract_address(operator);

    // revoke role 
    spill.revoke_role(default_admin_role, admin);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_revoke_non_existant_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    set_contract_address(admin);

    // revoke role 
    spill.revoke_role(default_admin_role, operator);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Cant revoke role from self', 'ENTRYPOINT_FAILED'))]
fn test_self_revoke_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    set_contract_address(admin);
    // revoke role 
    spill.revoke_role(admin_role, admin);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Caller is missing role', 'ENTRYPOINT_FAILED'))]
fn test_renounce_non_existant_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    set_contract_address(operator);

    spill.renounce_role(default_admin_role, operator);
}

#[test]
#[available_gas(2000000000)]
#[should_panic(expected: ('Can only renounce role for self', 'ENTRYPOINT_FAILED'))]
fn test_invalid_slef_renounce_role() {
    let (spill, trait_cat, registry, eth) = utils::setup();

    let admin = vars::ADMIN();
    let operator = vars::OPERATOR();

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;
    set_contract_address(admin);
    spill.renounce_role(default_admin_role, operator);
}
