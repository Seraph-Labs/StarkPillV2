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
use starkpill::components::erc721::metadata::utils as uri_utils;
use debug::PrintTrait;


#[test]
#[available_gas(2000000000)]
fn test_full_pill_metadta() {
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
    set_contract_address(user);
    // mint eth to operator
    eth.mint(user, one_eth);
    // approve eth to spill contract 
    eth.approve(spill.contract_address, one_eth);

    // mint pill with 1 premium ing and 1 premium bg + tips
    let spent_eth = pill_base_price + ing_price + bg_price + tip_price;
    let calldata = utils::get_mint_pill_calldata(user, 1, 1, spent_eth);
    spill.execute_system(registry.contract_address, 1, calldata);

    let calldata = utils::get_mint_pill_calldata(user, 0, 0, pill_base_price);
    spill.execute_system(registry.contract_address, 1, calldata);

    // vote with fame once 
    let calldata = utils::get_vbooth_calldata(1, 1, true);
    spill.execute_system(registry.contract_address, 2, calldata);
    // vote with defame once 
    let calldata = utils::get_vbooth_calldata(1, 1, false);
    spill.execute_system(registry.contract_address, 2, calldata);
// let uri = spill.token_uri(1);
// uri.print();

// let uri = spill.token_uri(2);
// uri.print();

// let uri = spill.token_uri(3);
// uri.print();

// let uri = spill.token_uri(4);
// uri.print();
}
