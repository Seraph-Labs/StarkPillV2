use starknet::{ContractAddress, ClassHash};
use seraphlabs::tokens::erc2114::utils::AttrType;
use souk::systems::utils::{SystemStatus, SystemStatusTrait};

#[starknet::interface]
trait IStarkPill<TContractState> {
    // ----------------------------- access control ----------------------------- //
    // @dev added ny embed
    fn has_role(self: @TContractState, role: felt252, account: ContractAddress) -> bool;
    fn get_role_admin(self: @TContractState, role: felt252) -> felt252;
    fn grant_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn revoke_role(ref self: TContractState, role: felt252, account: ContractAddress);
    fn renounce_role(ref self: TContractState, role: felt252, account: ContractAddress);
    // ------------------------------ introspection ----------------------------- //
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
    // --------------------------------- ERC721 --------------------------------- //
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn token_uri(self: @TContractState, token_id: u256) -> Array<felt252>;
    fn set_token_uri(ref self: TContractState, base_uri: Array<felt252>);
    // base 
    fn balance_of(self: @TContractState, owner: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
    fn approve(ref self: TContractState, approved: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    // enum
    fn total_supply(self: @TContractState) -> u256;
    fn token_of_owner_by_index(self: @TContractState, owner: ContractAddress, index: u256) -> u256;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    // --------------------------------- ERC3525 -------------------------------- //
    fn slot_of(self: @TContractState, token_id: u256) -> u256;
    // --------------------------------- ERC2114 -------------------------------- //
    fn get_trait_catalog(self: @TContractState) -> ContractAddress;

    fn token_balance_of(self: @TContractState, token_id: u256) -> u256;

    fn token_of(self: @TContractState, token_id: u256) -> u256;

    fn token_of_token_by_index(self: @TContractState, token_id: u256, index: u256) -> u256;

    fn attribute_name(self: @TContractState, attr_id: u64) -> felt252;

    fn attribute_type(self: @TContractState, attr_id: u64) -> AttrType;

    fn attribute_value(self: @TContractState, token_id: u256, attr_id: u64) -> felt252;

    fn attributes_of(self: @TContractState, token_id: u256) -> Span<u64>;

    fn scalar_transfer_from(
        ref self: TContractState, from: ContractAddress, token_id: u256, to_token_id: u256
    );

    fn scalar_remove_from(ref self: TContractState, from_token_id: u256, token_id: u256);

    // slot attributes
    fn slot_attributes_of(self: @TContractState, slot_id: u256) -> Span<u64>;

    // inventory
    fn equipped_attribute_value(self: @TContractState, token_id: u256, attr_id: u64) -> felt252;

    fn is_inside_inventory(self: @TContractState, token_id: u256, child_id: u256) -> bool;

    fn token_supply_in_inventory(self: @TContractState, token_id: u256, criteria: u256) -> u64;

    fn inventory_of(self: @TContractState, token_id: u256) -> Span<u256>;

    fn inventory_attributes_of(self: @TContractState, slot_id: u256) -> Span<u64>;

    fn slot_criteria_capacity(self: @TContractState, slot_id: u256, criteria: u256) -> u64;

    fn set_slot_criteria(ref self: TContractState, slot_id: u256, criteria: u256, capacity: u64);

    fn set_inventory_attributes(ref self: TContractState, slot_id: u256, attr_ids: Span<u64>);

    // ------------------------------ Souk Terminal ----------------------------- //
    fn system_status(
        self: @TContractState, registry: ContractAddress, system_id: u128
    ) -> SystemStatus;

    fn install_system(
        ref self: TContractState,
        registry: ContractAddress,
        system_id: u128,
        version: u64,
        system_calldata: Array<felt252>
    );

    fn uninstall_system(ref self: TContractState, registry: ContractAddress, system_id: u128);

    fn execute_system(
        ref self: TContractState,
        registry: ContractAddress,
        system_id: u128,
        system_calldata: Array<felt252>
    ) -> Span<felt252>;
}

#[starknet::contract]
mod StarkPill {
    use core::zeroable::Zeroable;
    use super::{ContractAddress, ClassHash};
    use super::AttrType;
    use super::{SystemStatus, SystemStatusTrait};
    use starknet::get_caller_address;
    use starkpill::constants;

    use starkpill::components::access::AccessControlComponent;
    use starkpill::components::roles::AdminRoleComponent;
    // token components
    use seraphlabs::tokens::src5::SRC5Component;
    use seraphlabs::tokens::erc721::{ERC721Component, extensions::ERC721EnumComponent};
    use starkpill::components::erc721::ERC721MetadataComponent;
    use seraphlabs::tokens::erc3525::ERC3525Component;
    use seraphlabs::tokens::erc2114::{
        ERC2114Component, extensions::{ERC2114InvComponent, ERC2114SlotAttrComponent}
    };
    // souk components
    use souk::systems::SoukTermComponent;

    // access impls
    use AccessControlComponent::{AccessControlInitializerImpl};
    use AdminRoleComponent::{AdminRoleInitializerImpl, AdminRoleInternalImpl};
    // token impls
    use ERC721Component::{IERC721Impl, ERC721InitializerImpl};
    use ERC721MetadataComponent::{ERC721MetadataInitializerImpl, ERC721MetadataInternalImpl};
    use ERC721EnumComponent::{IERC721EnumImpl, ERC721EnumInternalImpl, ERC721EnumInitializerImpl};
    use ERC3525Component::{ERC3525InitializerImpl, ERC3525InternalImpl, IERC3525Impl};
    use ERC2114Component::{ERC2114InternalImpl, ERC2114InitializerImpl, IERC2114Impl};
    use ERC2114InvComponent::{
        IERC2114InvImpl, ERC2114InvInternalImpl, ERC2114InvPrivateImpl, ERC2114InvInitializerImpl
    };
    use ERC2114SlotAttrComponent::{
        IERC2114SlotAttrImpl, ERC2114SlotAttrInternalImpl, ERC2114SlotAttrInitializerImpl
    };
    // souk impls
    use SoukTermComponent::{SoukTermInitializerImpl, ISoukTermImpl};

    // access
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: AdminRoleComponent, storage: admin_role, event: AdminRoleEvent);
    // tokens
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: ERC721MetadataComponent, storage: erc721_metadata, event: ERC721MetadataEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721EnumComponent, storage: erc721_enum, event: ERC721EnumEvent);
    component!(path: ERC3525Component, storage: erc3525, event: ERC3525Event);
    component!(path: ERC2114Component, storage: erc2114, event: ERC2114Event);
    component!(path: ERC2114InvComponent, storage: erc2114_inv, event: ERC2114InvEvent);
    component!(
        path: ERC2114SlotAttrComponent, storage: erc2114_slot_attr, event: ERC2114SlotAttrEvent
    );
    // souk
    component!(path: SoukTermComponent, storage: souk_term, event: SoukTermEvent);

    // -------------------------------------------------------------------------- //
    //                                   Embeds                                   //
    // -------------------------------------------------------------------------- //
    // --------------------------------- access --------------------------------- //
    #[abi(embed_v0)]
    impl AccessControl = AccessControlComponent::AccessControlImpl<ContractState>;

    // --------------------------------- tokens --------------------------------- //

    #[abi(embed_v0)]
    impl SRC5 = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl ERC721Metadata =
        ERC721MetadataComponent::ERC721MetadataImpl<ContractState>;

    // -------------------------------------------------------------------------- //
    //                                   Storage                                  //
    // -------------------------------------------------------------------------- //

    #[storage]
    struct Storage {
        // access
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        admin_role: AdminRoleComponent::Storage,
        // introspection
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        // tokens
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_metadata: ERC721MetadataComponent::Storage,
        #[substorage(v0)]
        erc721_enum: ERC721EnumComponent::Storage,
        #[substorage(v0)]
        erc3525: ERC3525Component::Storage,
        #[substorage(v0)]
        erc2114: ERC2114Component::Storage,
        #[substorage(v0)]
        erc2114_inv: ERC2114InvComponent::Storage,
        #[substorage(v0)]
        erc2114_slot_attr: ERC2114SlotAttrComponent::Storage,
        // souk
        #[substorage(v0)]
        souk_term: SoukTermComponent::Storage,
    }

    // -------------------------------------------------------------------------- //
    //                                   Events                                   //
    // -------------------------------------------------------------------------- //

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        // access
        AccessControlEvent: AccessControlComponent::Event,
        AdminRoleEvent: AdminRoleComponent::Event,
        // introspection
        SRC5Event: SRC5Component::Event,
        // tokens
        ERC721Event: ERC721Component::Event,
        ERC721MetadataEvent: ERC721MetadataComponent::Event,
        ERC721EnumEvent: ERC721EnumComponent::Event,
        ERC3525Event: ERC3525Component::Event,
        ERC2114Event: ERC2114Component::Event,
        ERC2114InvEvent: ERC2114InvComponent::Event,
        ERC2114SlotAttrEvent: ERC2114SlotAttrComponent::Event,
        // souk
        SoukTermEvent: SoukTermComponent::Event,
    }

    // -------------------------------------------------------------------------- //
    //                                 Constructor                                //
    // -------------------------------------------------------------------------- //
    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: felt252,
        symbol: felt252,
        trait_catalog: ContractAddress
    ) {
        assert(get_caller_address().is_non_zero(), "Invalid Caller");
        assert(admin.is_non_zero(), "Invalid admin");
        // ------------------------------- initalizers ------------------------------ //
        // access
        // @dev emits 2 RoleGranted event
        // grants DEFAULT_ADMIN_ROLE = 0, to admin
        self.access_control.initializer(admin);
        // grants ADMIN_ROLE = 'ADMIN_ROLE', to admin
        self.admin_role.initializer(admin);
        // tokens
        self.erc721.initializer();
        self.erc721_metadata.initializer(name, symbol);
        self.erc721_enum.initializer();
        self.erc3525.initializer(0);
        // @dev emits 1 TraitCatalogAttached event
        self.erc2114.initializer(trait_catalog);
        self.erc2114_slot_attr.initializer();
        self.erc2114_inv.initializer();
        // souk
        self.souk_term.initializer();

        let pill_slot = constants::PILL_SLOT;
        let ing_slot = constants::ING_SLOT;
        let bg_slot = constants::BG_SLOT;
        let name_id = constants::NAME_ID;
        let ing_id = constants::ING_ID;
        let bg_id = constants::BG_ID;
        let mbill_id = constants::MBILL_ID;
        let fame_id = constants::FAME_ID;
        let defame_id = constants::DEFAME_ID;
        // ---------------------------- create attributes --------------------------- //
        // @dev emits 6 AttributeCreated events
        // attr_id 1 : name, from list_id 1
        self.erc2114.create_attribute(name_id, AttrType::String(1), '"name"');
        // attr_id 2 : ingredient, from list_id 2
        self.erc2114.create_attribute(ing_id, AttrType::String(2), '"Ingredient"');
        // attr_id 3 : background, list_id 3 
        self.erc2114.create_attribute(bg_id, AttrType::String(3), '"Background"');
        // attr_id 4 : medical bill
        self.erc2114.create_attribute(mbill_id, AttrType::Number(0), '"Medical Bill"');
        // attr_id 5 : fame 
        self.erc2114.create_attribute(fame_id, AttrType::Number(0), '"Fame"');
        // attr_id 6 : defame 
        self.erc2114.create_attribute(defame_id, AttrType::Number(0), '"DeFame"');
        // --------------------------- set slot attributes -------------------------- //
        // @dev emits 3 SlotAttributeUpdate events
        // slot_id 1 : name attr_id index 1 -> "TestPill" or "StarkPill"
        self.erc2114_slot_attr.set_slot_attribute(pill_slot, name_id, 1);
        // slot_id 2 : name attr_id index 2 -> "PillIngredient" 
        self.erc2114_slot_attr.set_slot_attribute(ing_slot, name_id, 2);
        // slot_id 3 : name attr_id index 3 -> "PillBackground" 
        self.erc2114_slot_attr.set_slot_attribute(bg_slot, name_id, 3);
        // ----------------------- set inventory slot criteria ---------------------- //
        // @dev emits 2 InventorySlotCriteria events
        // use internal function to save gas
        // sets Pill Slot tokens to hold 1 ING Slot tokens in inventory
        self.erc2114_inv._edit_slot_criteria(pill_slot, ing_slot, 1);
        // sets Pill Slot tokens to hold 1 BG Slot tokens in inventory
        self.erc2114_inv._edit_slot_criteria(pill_slot, bg_slot, 1);
        // ------------------------ set inventory attributes ------------------------ //
        // @dev emits 1 InventoryAttributes event
        // set inheritable attributes for pill slot as [ing_id, bg_id, mbill_id]
        self
            .erc2114_inv
            ._attach_attr_ids_to_inventory(pill_slot, array![ing_id, bg_id, mbill_id].span());
    }

    // -------------------------------------------------------------------------- //
    //                             StarkPill Functions                            //
    // -------------------------------------------------------------------------- //
    #[generate_trait]
    #[external(v0)]
    impl BaseStarkPillImpl of BaseStarkPillTrait {
        // -------------------------------------------------------------------------- //
        //                                   ERC721                                   //
        // -------------------------------------------------------------------------- //

        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            self.erc721.balance_of(owner)
        }

        fn owner_of(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721.owner_of(token_id)
        }

        fn get_approved(self: @ContractState, token_id: u256) -> ContractAddress {
            self.erc721.get_approved(token_id)
        }

        fn is_approved_for_all(
            self: @ContractState, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self.erc721.is_approved_for_all(owner, operator)
        }

        fn approve(ref self: ContractState, approved: ContractAddress, token_id: u256) {
            self.erc721.approve(approved, token_id);
        }

        fn set_approval_for_all(
            ref self: ContractState, operator: ContractAddress, approved: bool
        ) {
            self.erc721.set_approval_for_all(operator, approved);
        }

        // -------------------------------- metadata -------------------------------- //

        fn set_token_uri(ref self: ContractState, base_uri: Array<felt252>) {
            self.admin_role._assert_only_admin();
            self.erc721_metadata._set_base_uri(base_uri);
        }

        // ------------------------------- ennumerable ------------------------------ //

        fn total_supply(self: @ContractState) -> u256 {
            self.erc721_enum.total_supply()
        }

        fn token_of_owner_by_index(
            self: @ContractState, owner: ContractAddress, index: u256
        ) -> u256 {
            self.erc721_enum.token_of_owner_by_index(owner, index)
        }

        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, token_id: u256
        ) {
            // assert token is not parent
            self.erc2114._assert_token_no_parent(token_id);
            // clear 3525 approvals
            self.erc3525._clear_value_approvals(token_id);
            // transfer token 
            self.erc721_enum.transfer_from(from, to, token_id);
        }

        // -------------------------------------------------------------------------- //
        //                                   ERC3525                                  //
        // -------------------------------------------------------------------------- //

        fn slot_of(self: @ContractState, token_id: u256) -> u256 {
            self.erc3525.slot_of(token_id)
        }

        // -------------------------------------------------------------------------- //
        //                                   ERC2114                                  //
        // -------------------------------------------------------------------------- //

        fn get_trait_catalog(self: @ContractState) -> ContractAddress {
            self.erc2114.get_trait_catalog()
        }

        fn token_balance_of(self: @ContractState, token_id: u256) -> u256 {
            self.erc2114.token_balance_of(token_id)
        }

        fn token_of(self: @ContractState, token_id: u256) -> u256 {
            self.erc2114.token_of(token_id)
        }

        fn token_of_token_by_index(self: @ContractState, token_id: u256, index: u256) -> u256 {
            self.erc2114.token_of_token_by_index(token_id, index)
        }

        fn attribute_name(self: @ContractState, attr_id: u64) -> felt252 {
            self.erc2114.attribute_name(attr_id)
        }

        fn attribute_type(self: @ContractState, attr_id: u64) -> AttrType {
            self.erc2114.attribute_type(attr_id)
        }

        fn attribute_value(self: @ContractState, token_id: u256, attr_id: u64) -> felt252 {
            self.erc2114.attribute_value(token_id, attr_id)
        }

        fn attributes_of(self: @ContractState, token_id: u256) -> Span<u64> {
            self.erc2114.attributes_of(token_id)
        }

        fn scalar_transfer_from(
            ref self: ContractState, from: ContractAddress, token_id: u256, to_token_id: u256
        ) {
            // use inventory component function instead to equip and unequip tokens
            self.erc2114_inv.scalar_transfer_from(from, token_id, to_token_id);
        }

        fn scalar_remove_from(ref self: ContractState, from_token_id: u256, token_id: u256) {
            // use inventory component function instead to equip and unequip tokens
            self.erc2114_inv.scalar_remove_from(from_token_id, token_id);
        }

        // ----------------------------- slot attribute ----------------------------- //
        fn slot_attributes_of(self: @ContractState, slot_id: u256) -> Span<u64> {
            self.erc2114_slot_attr.slot_attributes_of(slot_id)
        }

        // -------------------------------- inventory ------------------------------- //

        fn equipped_attribute_value(self: @ContractState, token_id: u256, attr_id: u64) -> felt252 {
            self.erc2114_inv.equipped_attribute_value(token_id, attr_id)
        }

        fn is_inside_inventory(self: @ContractState, token_id: u256, child_id: u256) -> bool {
            self.erc2114_inv.is_inside_inventory(token_id, child_id)
        }

        fn token_supply_in_inventory(self: @ContractState, token_id: u256, criteria: u256) -> u64 {
            self.erc2114_inv.token_supply_in_inventory(token_id, criteria)
        }

        fn inventory_of(self: @ContractState, token_id: u256) -> Span<u256> {
            self.erc2114_inv.inventory_of(token_id)
        }

        fn inventory_attributes_of(self: @ContractState, slot_id: u256) -> Span<u64> {
            self.erc2114_inv.inventory_attributes_of(slot_id)
        }

        fn slot_criteria_capacity(self: @ContractState, slot_id: u256, criteria: u256) -> u64 {
            self.erc2114_inv.slot_criteria_capacity(slot_id, criteria)
        }

        fn set_slot_criteria(
            ref self: ContractState, slot_id: u256, criteria: u256, capacity: u64
        ) {
            self.admin_role._assert_only_admin();
            self.erc2114_inv.set_slot_criteria(slot_id, criteria, capacity);
        }

        fn set_inventory_attributes(ref self: ContractState, slot_id: u256, attr_ids: Span<u64>) {
            self.admin_role._assert_only_admin();
            self.erc2114_inv.set_inventory_attributes(slot_id, attr_ids);
        }

        // -------------------------------------------------------------------------- //
        //                                Souk Terminal                               //
        // -------------------------------------------------------------------------- //
        fn system_status(
            self: @ContractState, registry: ContractAddress, system_id: u128
        ) -> SystemStatus {
            self.souk_term.system_status(registry, system_id)
        }

        fn install_system(
            ref self: ContractState,
            registry: ContractAddress,
            system_id: u128,
            version: u64,
            system_calldata: Array<felt252>
        ) {
            self.admin_role._assert_only_admin();
            self.souk_term.install_system(registry, system_id, version, system_calldata);
        }

        fn uninstall_system(ref self: ContractState, registry: ContractAddress, system_id: u128) {
            self.admin_role._assert_only_admin();
            self.souk_term.uninstall_system(registry, system_id);
        }

        fn execute_system(
            ref self: ContractState,
            registry: ContractAddress,
            system_id: u128,
            system_calldata: Array<felt252>
        ) -> Span<felt252> {
            self.souk_term.execute_system(registry, system_id, system_calldata)
        }
    }
}
