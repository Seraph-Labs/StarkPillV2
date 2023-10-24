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
fn test_spill_deploy() {
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
    let admin = vars::ADMIN();
    let owner = vars::OWNER();
    let pill_slot = spill_constants::PILL_SLOT;
    let ing_slot = spill_constants::ING_SLOT;
    let bg_slot = spill_constants::BG_SLOT;
    let name_id = spill_constants::NAME_ID;
    let ing_id = spill_constants::ING_ID;
    let bg_id = spill_constants::BG_ID;
    let mbill_id = spill_constants::MBILL_ID;
    let fame_id = spill_constants::FAME_ID;
    let defame_id = spill_constants::DEFAME_ID;

    let name_id_name = spill_constants::NAME_ID_NAME;
    let ing_id_name = spill_constants::ING_ID_NAME;
    let bg_id_name = spill_constants::BG_ID_NAME;
    let mbill_id_name = spill_constants::MBILL_ID_NAME;
    let fame_id_name = spill_constants::FAME_ID_NAME;
    let defame_id_name = spill_constants::DEFAME_ID_NAME;

    let default_admin_role = spill_constants::DEFAULT_ADMIN_ROLE;
    let admin_role = spill_constants::ADMIN_ROLE;

    let pill_inv_attrs = array![ing_id, bg_id, mbill_id].span();
    // ---------------------------- check interfaces ---------------------------- //
    assert(
        spill.supports_interface(spill_constants::IACCESSCONTROL_ID), 'no access control interface'
    );
    assert(spill.supports_interface(constants::IERC721_ID), 'no erc721 interface');
    assert(spill.supports_interface(constants::IERC721_ENUMERABLE_ID), 'no erc721 enum interface');
    assert(spill.supports_interface(constants::IERC721_METADATA_ID), 'no erc721 meta interface');
    assert(spill.supports_interface(constants::IERC3525_ID), 'no erc3525 interface');
    assert(spill.supports_interface(constants::IERC2114_ID), 'no erc2114 interface');
    assert(
        spill.supports_interface(constants::IERC2114_SLOT_ATTRIBUTE_ID),
        'no erc2114 slotAttr interface'
    );
    assert(spill.supports_interface(constants::IERC2114_INVENTORY_ID), 'no erc2114 inv interface');
    assert(spill.supports_interface(souk_constants::ISOUK_TERMINAL_ID), 'no terminal interface');

    // ------------------------------- check access ------------------------------ //
    assert(spill.has_role(default_admin_role, admin), 'default role not set');
    assert(spill.has_role(admin_role, admin), 'admin role not set');
    assert(spill.get_role_admin(admin_role) == default_admin_role, 'role admin not set');
    // --------------------------- check pill premium --------------------------- //
    assert(
        spill.get_eth_premium(name_id, 1) == spill_constants::PILL_BASE_PRICE, 'wrong pill premium'
    );
    assert(spill.get_pharmacy_addresses(true, 0) == eth_addr, 'wrong eth address');
    assert(spill.get_pharmacy_addresses(false, 0) == owner, 'wrong wallet address');

    // ------------------------- check contract metadata ------------------------ //
    assert(spill.name() == spill_constants::NAME, 'wrong name');
    assert(spill.symbol() == spill_constants::SYMBOL, 'wrong symbol');
    // ----------------------------- check trait cat ---------------------------- //
    assert(spill.get_trait_catalog() == trait_cat_addr, 'wrong trait cat');
    // ---------------------------- check attributes ---------------------------- //
    assert(spill.attribute_name(name_id) == name_id_name, 'wrong name attr');
    assert(spill.attribute_name(ing_id) == ing_id_name, 'wrong ing attr');
    assert(spill.attribute_name(bg_id) == bg_id_name, 'wrong bg attr');
    assert(spill.attribute_name(mbill_id) == mbill_id_name, 'wrong mbill attr');
    assert(spill.attribute_name(fame_id) == fame_id_name, 'wrong fame attr');
    assert(spill.attribute_name(defame_id) == defame_id_name, 'wrong defame attr');
    assert(spill.attribute_type(name_id) == AttrType::String(1), 'wrong name attr type');
    assert(spill.attribute_type(ing_id) == AttrType::String(2), 'wrong ing attr type');
    assert(spill.attribute_type(bg_id) == AttrType::String(3), 'wrong bg attr type');
    assert(spill.attribute_type(mbill_id) == AttrType::Number(0), 'wrong mbill attr type');
    assert(spill.attribute_type(fame_id) == AttrType::Number(0), 'wrong fame attr type');
    assert(spill.attribute_type(defame_id) == AttrType::Number(0), 'wrong defame attr type');
    // -------------------------- check slot attributes ------------------------- //
    assert(spill.slot_attributes_of(pill_slot) == array![name_id].span(), 'wrong pill slot attr');
    assert(spill.slot_attributes_of(ing_slot) == array![name_id].span(), 'wrong ing slot attr');
    assert(spill.slot_attributes_of(bg_slot) == array![name_id].span(), 'wrong bg slot attr');
    assert(
        spill.slot_attribute_value(pill_slot, name_id) == spill_constants::PILL_NAME,
        'worng pill slot attr value'
    );
    assert(
        spill.slot_attribute_value(ing_slot, name_id) == spill_constants::ING_NAME,
        'worng ing slot attr value'
    );
    assert(
        spill.slot_attribute_value(bg_slot, name_id) == spill_constants::BG_NAME,
        'worng bg slot attr value'
    );
    // ----------------- check inventory slot criteria capacity ----------------- //
    assert(spill.slot_criteria_capacity(pill_slot, ing_slot) == 1, 'wrong inv ing slot capacity');
    assert(spill.slot_criteria_capacity(pill_slot, bg_slot) == 1, 'wrong inv bg slot capacity');
    // ----------------------- check inventory attributes ----------------------- //
    assert(spill.inventory_attributes_of(pill_slot) == pill_inv_attrs, 'wrong pill inv attr');
    // ------------------------------- test events ------------------------------ //
    utils::assert_role_granted_event(starkpill_addr, default_admin_role, admin, admin,);
    utils::assert_role_granted_event(starkpill_addr, admin_role, admin, admin,);
    utils::assert_pharmacy_premium_event(
        starkpill_addr, name_id, 1, eth_addr, spill_constants::PILL_BASE_PRICE,
    );
    utils::assert_trait_catalog_attached_event(starkpill_addr, admin, trait_cat_addr,);
    utils::assert_attribute_created_event(
        starkpill_addr, name_id, AttrType::String(1), name_id_name,
    );
    utils::assert_attribute_created_event(
        starkpill_addr, ing_id, AttrType::String(2), ing_id_name,
    );
    utils::assert_attribute_created_event(starkpill_addr, bg_id, AttrType::String(3), bg_id_name,);
    utils::assert_attribute_created_event(
        starkpill_addr, mbill_id, AttrType::Number(0), mbill_id_name,
    );
    utils::assert_attribute_created_event(
        starkpill_addr, fame_id, AttrType::Number(0), fame_id_name,
    );
    utils::assert_attribute_created_event(
        starkpill_addr, defame_id, AttrType::Number(0), defame_id_name,
    );
    utils::assert_slot_attribute_update_event(
        starkpill_addr, pill_slot, name_id, AttrType::String(1), 0, 1
    );
    utils::assert_slot_attribute_update_event(
        starkpill_addr, ing_slot, name_id, AttrType::String(1), 0, 2
    );
    utils::assert_slot_attribute_update_event(
        starkpill_addr, bg_slot, name_id, AttrType::String(1), 0, 3
    );
    utils::assert_inventory_slot_criteria_event(starkpill_addr, pill_slot, ing_slot, 0, 1);
    utils::assert_inventory_slot_criteria_event(starkpill_addr, pill_slot, bg_slot, 0, 1);
    utils::assert_inventory_attributes_event(starkpill_addr, pill_slot, pill_inv_attrs);
    // ------------------------------ setup events ------------------------------ //
    utils::assert_system_status_update_event(starkpill_addr, registry_addr, 1, 0, 1);
    utils::assert_system_status_update_event(starkpill_addr, registry_addr, 2, 0, 1);
    helper::assert_no_events_left(starkpill_addr);
}
