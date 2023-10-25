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
use starkpill::components::access::AccessControlComponent;
use starkpill::components::pharmacy::PharmacyComponent;
use seraphlabs::tokens::erc2114::{
    ERC2114Component, extensions::{ERC2114InvComponent, ERC2114SlotAttrComponent}
};
use souk::systems::SoukTermComponent;
use seraphlabs::tokens::erc3525::ERC3525Component;
use seraphlabs::tokens::erc721::ERC721Component;
use starkpill::constants as spill_constants;
use souk::constants as souk_constants;
use souk::systems::utils::{SystemStatus, SystemStatusTrait};
use seraphlabs::tokens::erc2114::utils::AttrType;
use seraphlabs::tokens::constants;
use seraphlabs::utils::testing::{vars, helper};
use starknet::{ContractAddress, ClassHash};
use starknet::testing::{set_caller_address, set_contract_address, pop_log, pop_log_raw};
use debug::PrintTrait;

// -------------------------------------------------------------------------- //
//                                  constants                                 //
// -------------------------------------------------------------------------- //

#[inline(always)]
fn BASEURI() -> Array<felt252> {
    let mut base_uri = ArrayTrait::<felt252>::new();
    base_uri.append('3tsgIKE0d0F-56pDXRpm2E7a-_c-IfU');
    base_uri.append('JB7wyhwDhr9o');
    base_uri
}

// -------------------------------------------------------------------------- //
//                            deployment functions                            //
// -------------------------------------------------------------------------- //

#[inline(always)]
fn setup_eth() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let contract_address = helper::deploy(EthMock::TEST_CLASS_HASH, calldata);
    contract_address
}

#[inline(always)]
fn setup_trait_catalog() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let admin = vars::ADMIN();
    Serde::serialize(@admin, ref calldata);
    // set admin caller
    set_contract_address(admin);
    let contract_address = helper::deploy(TraitCat::TEST_CLASS_HASH, calldata);
    let mock = ITraitCatalogDispatcher { contract_address };
    // generate ingredient trait list
    mock.generate_trait_list(array!['Cairo Cap', 'Pepe', 'Apibara', 'Wojak'].span());
    // generate background trait list
    mock
        .generate_trait_list(
            array!['Yellow', 'Rocket', 'Cloudy Kingdom', 'Training Grounds'].span()
        );
    contract_address
}

#[inline(always)]
fn setup_system_registry() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let admin = vars::ADMIN();
    Serde::serialize(@admin, ref calldata);
    // set admin caller
    set_contract_address(admin);
    let contract_address = helper::deploy(Registry::TEST_CLASS_HASH, calldata);
    let mock = ISoukSystemRegistryDispatcher { contract_address };
    // register mint system
    mock.register_system(MintPillSystem::TEST_CLASS_HASH.try_into().unwrap());
    mock.register_system(VBoothSystem::TEST_CLASS_HASH.try_into().unwrap());
    contract_address
}

#[inline(always)]
fn setup_starkpill(
    eth: ContractAddress, trait_cat: ContractAddress, registry: ContractAddress
) -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    let admin = vars::ADMIN();
    let wallet = vars::OWNER();
    Serde::serialize(@admin, ref calldata);
    Serde::serialize(@wallet, ref calldata);
    Serde::serialize(@eth, ref calldata);
    Serde::serialize(@trait_cat, ref calldata);
    // set admin caller
    set_contract_address(admin);
    let contract_address = helper::deploy(SPill::TEST_CLASS_HASH, calldata);
    let mock = IStarkPillDispatcher { contract_address };
    // install mint systems 
    mock.install_system(registry, 1, 1, array![]);
    // install vbooth systems 
    mock.install_system(registry, 2, 1, array![]);
    // set base uri
    mock.set_token_uri(BASEURI());
    contract_address
}

fn setup() -> (
    IStarkPillDispatcher,
    ITraitCatalogDispatcher,
    ISoukSystemRegistryDispatcher,
    IERC20MintableDispatcher
) {
    // deploy eth mock
    let eth = setup_eth();
    // deploy trait catalog
    let trait_cat = setup_trait_catalog();
    // deploy system registry
    let registry = setup_system_registry();
    // deploy starkpill
    let starkpill = setup_starkpill(eth, trait_cat, registry);
    // return dispatcher
    let mock = IStarkPillDispatcher { contract_address: starkpill };
    // return dispatcher
    let trait_cat_mock = ITraitCatalogDispatcher { contract_address: trait_cat };
    // return dispatcher
    let registry_mock = ISoukSystemRegistryDispatcher { contract_address: registry };
    let eth_mock = IERC20MintableDispatcher { contract_address: eth };
    (mock, trait_cat_mock, registry_mock, eth_mock)
}

// -------------------------------------------------------------------------- //
//                                   Others                                   //
// -------------------------------------------------------------------------- //

#[inline(always)]
fn get_mint_pill_calldata(
    to: ContractAddress, ing: felt252, bg: felt252, price: u256
) -> Array<felt252> {
    let mut calldata = ArrayTrait::new();
    Serde::serialize(@to, ref calldata);
    Serde::serialize(@ing, ref calldata);
    Serde::serialize(@bg, ref calldata);
    Serde::serialize(@price, ref calldata);
    calldata
}

#[inline(always)]
fn get_vbooth_calldata(token_id: u256, ammount: felt252, vote: bool) -> Array<felt252> {
    let mut calldata = ArrayTrait::new();
    Serde::serialize(@token_id, ref calldata);
    Serde::serialize(@ammount, ref calldata);
    Serde::serialize(@vote, ref calldata);
    calldata
}

// -------------------------------------------------------------------------- //
//                                event testers                               //
// -------------------------------------------------------------------------- //

// ------------------------------ AccessControl ----------------------------- //

#[inline(always)]
fn assert_role_granted_event(
    contract_addr: ContractAddress,
    role: felt252,
    account: ContractAddress,
    sender: ContractAddress,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::AccessControlEvent(
            AccessControlComponent::Event::RoleGranted(
                AccessControlComponent::RoleGranted { role, account, sender }
            )
        ),
        'wrong RoleGranted'
    );
}

#[inline(always)]
fn assert_role_revoked_event(
    contract_addr: ContractAddress,
    role: felt252,
    account: ContractAddress,
    sender: ContractAddress,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::AccessControlEvent(
            AccessControlComponent::Event::RoleRevoked(
                AccessControlComponent::RoleRevoked { role, account, sender }
            )
        ),
        'wrong RoleRevoked'
    );
}

#[inline(always)]
fn assert_role_admin_changed_event(
    contract_addr: ContractAddress,
    role: felt252,
    previous_admin_role: felt252,
    new_admin_role: felt252,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::AccessControlEvent(
            AccessControlComponent::Event::RoleAdminChanged(
                AccessControlComponent::RoleAdminChanged {
                    role, previous_admin_role, new_admin_role
                }
            )
        ),
        'wrong RoleAdminChanged'
    );
}
// -------------------------------- Pharmacy -------------------------------- //

#[inline(always)]
fn assert_pharmacy_stock_update_event(
    contract_addr: ContractAddress, attr_id: u64, index: felt252, numerator: u128, denominator: u128
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::PharmacyEvent(
            PharmacyComponent::Event::PharmacyStockUpdate(
                PharmacyComponent::PharmacyStockUpdate { attr_id, index, numerator, denominator }
            )
        ),
        'wrong PharmacyStockUpdate'
    );
}

#[inline(always)]
fn assert_pharmacy_premium_event(
    contract_addr: ContractAddress,
    attr_id: u64,
    index: felt252,
    currency: ContractAddress,
    ammount: u256
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::PharmacyEvent(
            PharmacyComponent::Event::PharmacyPremium(
                PharmacyComponent::PharmacyPremium { attr_id, index, currency, ammount }
            )
        ),
        'wrong PharmacyPremium'
    );
}

#[inline(always)]
fn assert_pharmacy_l2_redemption_event(
    contract_addr: ContractAddress,
    project_address: ContractAddress,
    token_id: u256,
    received_token_id: u256,
    to: ContractAddress,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::PharmacyEvent(
            PharmacyComponent::Event::PharmacyL2Redemption(
                PharmacyComponent::PharmacyL2Redemption {
                    project_address, token_id, received_token_id, to
                }
            )
        ),
        'wrong PharmacyL2Redemption'
    );
}

#[inline(always)]
fn assert_pharmacy_l2_redemption_approval_event(
    contract_addr: ContractAddress,
    project_address: ContractAddress,
    attr_id: u64,
    index: felt252,
    approved: bool,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::PharmacyEvent(
            PharmacyComponent::Event::PharmacyL2RedemptionApproval(
                PharmacyComponent::PharmacyL2RedemptionApproval {
                    project_address, attr_id, index, approved
                }
            )
        ),
        'PharmacyL2RedemptionApproval'
    );
}
// --------------------------------- erc2114 -------------------------------- //

#[inline(always)]
fn assert_trait_catalog_attached_event(
    contract_addr: ContractAddress, from: ContractAddress, trait_catalog_addr: ContractAddress
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114Event(
            ERC2114Component::Event::TraitCatalogAttached(
                ERC2114Component::TraitCatalogAttached { from, trait_catalog_addr }
            )
        ),
        'wrong TraitCatalogAttached'
    );
}

// scalar transfer always emits a Transfer event first and then a ScalarTransfer event
// set drop to true if you want to drop the Transfer event
#[inline(always)]
fn assert_scalar_transfer_event(
    contract_addr: ContractAddress,
    from: ContractAddress,
    token_id: u256,
    to_token_id: u256,
    drop: bool
) {
    if drop {
        pop_log_raw(contract_addr);
    }

    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114Event(
            ERC2114Component::Event::ScalarTransfer(
                ERC2114Component::ScalarTransfer { from, token_id, to_token_id }
            )
        ),
        'wrong ScalarTransfer'
    );
}

#[inline(always)]
fn assert_scalar_remove_event(
    contract_addr: ContractAddress,
    from_token_id: u256,
    token_id: u256,
    to: ContractAddress,
    drop: bool
) {
    if drop {
        pop_log_raw(contract_addr);
    }

    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114Event(
            ERC2114Component::Event::ScalarRemove(
                ERC2114Component::ScalarRemove { from_token_id, token_id, to }
            )
        ),
        'wrong ScalarRemove'
    );
}

#[inline(always)]
fn assert_attribute_created_event(
    contract_addr: ContractAddress, attr_id: u64, attr_type: AttrType, name: felt252
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114Event(
            ERC2114Component::Event::AttributeCreated(
                ERC2114Component::AttributeCreated { attr_id, attr_type, name }
            )
        ),
        'wrong AttributeCreated'
    );
}

#[inline(always)]
fn assert_token_attribute_update_event(
    contract_addr: ContractAddress,
    token_id: u256,
    attr_id: u64,
    attr_type: AttrType,
    old_value: felt252,
    new_value: felt252
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114Event(
            ERC2114Component::Event::TokenAttributeUpdate(
                ERC2114Component::TokenAttributeUpdate {
                    token_id, attr_id, attr_type, old_value, new_value
                }
            )
        ),
        'wrong TokenAttributeUpdate'
    );
}

// ---------------------------- erc2114 slot attr --------------------------- //

#[inline(always)]
fn assert_slot_attribute_update_event(
    contract_addr: ContractAddress,
    slot_id: u256,
    attr_id: u64,
    attr_type: AttrType,
    old_value: felt252,
    new_value: felt252
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114SlotAttrEvent(
            ERC2114SlotAttrComponent::Event::SlotAttributeUpdate(
                ERC2114SlotAttrComponent::SlotAttributeUpdate {
                    slot_id, attr_id, attr_type, old_value, new_value
                }
            )
        ),
        'wrong SlotAttributeUpdate'
    );
}

// ---------------------------- erc2114 inventory --------------------------- //
#[inline(always)]
fn assert_inventory_slot_criteria_event(
    contract_addr: ContractAddress,
    slot_id: u256,
    criteria: u256,
    old_capacity: u64,
    new_capacity: u64
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114InvEvent(
            ERC2114InvComponent::Event::InventorySlotCriteria(
                ERC2114InvComponent::InventorySlotCriteria {
                    slot_id, criteria, old_capacity, new_capacity
                }
            )
        ),
        'wrong InventorySlotCriteria'
    );
}

#[inline(always)]
fn assert_inventory_attributes_event(
    contract_addr: ContractAddress, slot_id: u256, attr_ids: Span<u64>,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114InvEvent(
            ERC2114InvComponent::Event::InventoryAttributes(
                ERC2114InvComponent::InventoryAttributes { slot_id, attr_ids }
            )
        ),
        'wrong InventoryAttributes'
    );
}

#[inline(always)]
fn assert_inventory_updated_event(
    contract_addr: ContractAddress,
    token_id: u256,
    criteria: u256,
    child_id: u256,
    old_bal: u64,
    new_bal: u64
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC2114InvEvent(
            ERC2114InvComponent::Event::InventoryUpdated(
                ERC2114InvComponent::InventoryUpdated {
                    token_id, criteria, child_id, old_bal, new_bal
                }
            )
        ),
        'wrong InventoryUpdated'
    );
}

// -------------------------------- souk term ------------------------------- //

#[inline(always)]
fn assert_system_status_update_event(
    contract_addr: ContractAddress,
    registry: ContractAddress,
    system_id: u128,
    from_version: u64,
    to_version: u64,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::SoukTermEvent(
            SoukTermComponent::Event::SystemStatusUpdate(
                SoukTermComponent::SystemStatusUpdate {
                    registry, system_id, from_version, to_version
                }
            )
        ),
        'wrong SystemStatusUpdate event'
    );
}
// --------------------------------- ERC721 --------------------------------- //

#[inline(always)]
fn assert_transfer_event(
    contract_addr: ContractAddress, from: ContractAddress, to: ContractAddress, token_id: u256
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC721Event(
            ERC721Component::Event::Transfer(ERC721Component::Transfer { from, to, token_id })
        ),
        'Wrong Transfer Event'
    );
}

#[inline(always)]
fn assert_approval_event(
    contract_addr: ContractAddress,
    owner: ContractAddress,
    approved: ContractAddress,
    token_id: u256
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC721Event(
            ERC721Component::Event::Approval(
                ERC721Component::Approval { owner, approved, token_id }
            )
        ),
        'Wrong Approval Event'
    );
}

#[inline(always)]
fn assert_approval_for_all_event(
    contract_addr: ContractAddress,
    owner: ContractAddress,
    operator: ContractAddress,
    approved: bool
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC721Event(
            ERC721Component::Event::ApprovalForAll(
                ERC721Component::ApprovalForAll { owner, operator, approved }
            )
        ),
        'Wrong ApprovalForAll Event'
    );
}

// --------------------------------- ERC3525 -------------------------------- //

#[inline(always)]
fn assert_transfer_value_event(
    contract_addr: ContractAddress, from_token_id: u256, to_token_id: u256, value: u256,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC3525Event(
            ERC3525Component::Event::TransferValue(
                ERC3525Component::TransferValue { from_token_id, to_token_id, value }
            )
        ),
        'Wrong TransferValue Event'
    );
}

#[inline(always)]
fn assert_approval_value_event(
    contract_addr: ContractAddress, token_id: u256, operator: ContractAddress, value: u256,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC3525Event(
            ERC3525Component::Event::ApprovalValue(
                ERC3525Component::ApprovalValue { token_id, operator, value }
            )
        ),
        'Wrong ApprovalValue Event'
    );
}

#[inline(always)]
fn assert_slot_changed_event(
    contract_addr: ContractAddress, token_id: u256, old_slot: u256, new_slot: u256,
) {
    let event = pop_log::<SPill::Event>(contract_addr).unwrap();
    assert(
        event == SPill::Event::ERC3525Event(
            ERC3525Component::Event::SlotChanged(
                ERC3525Component::SlotChanged { token_id, old_slot, new_slot }
            )
        ),
        'Wrong SlotChanged Event'
    );
}

// --------------------------------- vbooth --------------------------------- //

#[inline(always)]
fn assert_pill_vote_event(
    contract_addr: ContractAddress,
    voter: ContractAddress,
    token_id: u256,
    vote: bool,
    ammount: felt252
) {
    let event = pop_log::<VBoothSystem::Event>(contract_addr).unwrap();
    assert(
        event == VBoothSystem::Event::PillVote(
            VBoothSystem::PillVote { voter, token_id, vote, ammount }
        ),
        'Wrong PillVote Event'
    );
}

#[inline(always)]
fn assert_pill_vote_time_stamp_event(
    contract_addr: ContractAddress, token_id: u256, time_stamp: u64,
) {
    let event = pop_log::<VBoothSystem::Event>(contract_addr).unwrap();
    assert(
        event == VBoothSystem::Event::PillVoteTimeStamp(
            VBoothSystem::PillVoteTimeStamp { token_id, time_stamp }
        ),
        'Wrong PillVoteTimeStamp Event'
    );
}

#[inline(always)]
fn assert_trait_vote_time_stamp_event(
    contract_addr: ContractAddress, pill_id: u256, token_id: u256, time_stamp: u64,
) {
    let event = pop_log::<VBoothSystem::Event>(contract_addr).unwrap();
    assert(
        event == VBoothSystem::Event::TraitVoteTimeStamp(
            VBoothSystem::TraitVoteTimeStamp { pill_id, token_id, time_stamp }
        ),
        'Wrong TraitVoteTimeStamp Event'
    );
}

// helpers
fn drop_all_events(address: ContractAddress) {
    loop {
        match pop_log_raw(address) {
            Option::Some(_) => { continue; },
            Option::None => { break; },
        };
    }
}
