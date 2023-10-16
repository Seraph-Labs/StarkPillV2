#[starknet::contract]
mod SPillTraitCatalog {
    use starkpill::components::roles::admin::AdminRoleComponent::AdminRoleInternalTrait;
    use starknet::{ContractAddress, get_caller_address};
    use starkpill::constants;
    use starkpill::components::access::AccessControlComponent;
    use starkpill::components::roles::AdminRoleComponent;
    use seraphlabs::tokens::erc2114::extensions::TraitCatalogComponent;
    use seraphlabs::tokens::src5::SRC5Component;
    use AccessControlComponent::{AccessControlInitializerImpl};
    use AdminRoleComponent::{AdminRoleInitializerImpl, AdminRoleInternalImpl};
    use TraitCatalogComponent::{ITraitCatalogImpl, TraitCatalogInitializerImpl};

    // access
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: AdminRoleComponent, storage: admin_role, event: AdminRoleEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: TraitCatalogComponent, storage: trait_catalog, event: TraitCatalogEvent);


    #[abi(embed_v0)]
    impl AccessControl = AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5 = SRC5Component::SRC5Impl<ContractState>;

    // -------------------------------------------------------------------------- //
    //                                   Storage                                  //
    // -------------------------------------------------------------------------- //

    #[storage]
    struct Storage {
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        admin_role: AdminRoleComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        trait_catalog: TraitCatalogComponent::Storage,
    }

    // -------------------------------------------------------------------------- //
    //                                   Events                                   //
    // -------------------------------------------------------------------------- //

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        AccessControlEvent: AccessControlComponent::Event,
        AdminRoleEvent: AdminRoleComponent::Event,
        SRC5Event: SRC5Component::Event,
        TraitCatalogEvent: TraitCatalogComponent::Event
    }

    // -------------------------------------------------------------------------- //
    //                                 Constructor                                //
    // -------------------------------------------------------------------------- //

    #[constructor]
    fn constructor(ref self: ContractState, admin: ContractAddress) {
        assert(get_caller_address().is_non_zero(), 'Invalid Caller');
        assert(admin.is_non_zero(), 'Invalid admin');

        // ------------------------------ initializers ------------------------------ //
        // @dev emits 2 RoleGranted event
        // grants DEFAULT_ADMIN_ROLE = 0, to admin
        self.access_control.initializer(admin);
        // grants ADMIN_ROLE = 'ADMIN_ROLE', to admin
        self.admin_role.initializer(admin);
        self.trait_catalog.initializer();
        // ------------------------------- create list ------------------------------ //
        // @dev emits 3 TraitListUpdate events
        //  creates list_id 1 -> name list
        self
            .trait_catalog
            .generate_trait_list(
                array![constants::PILL_NAME, constants::ING_NAME, constants::BG_NAME].span()
            );
    }

    // -------------------------------------------------------------------------- //
    //                           TraitCatalog Functions                           //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    #[external(v0)]
    impl SpillCatalogImpl of SpillCatalogTrait {
        fn trait_list_count(self: @ContractState) -> u64 {
            self.trait_catalog.trait_list_count()
        }

        fn trait_list_length(self: @ContractState, list_id: u64) -> felt252 {
            self.trait_catalog.trait_list_length(list_id)
        }

        fn trait_list_value_by_index(
            self: @ContractState, list_id: u64, index: felt252
        ) -> felt252 {
            self.trait_catalog.trait_list_value_by_index(list_id, index)
        }

        fn generate_trait_list(ref self: ContractState, values: Span<felt252>) -> u64 {
            self.admin_role._assert_only_admin();
            self.trait_catalog.generate_trait_list(values)
        }

        fn append_to_trait_list(ref self: ContractState, list_id: u64, value: felt252) {
            self.admin_role._assert_only_admin();
            self.trait_catalog.append_to_trait_list(list_id, value);
        }

        fn append_batch_to_trait_list(
            ref self: ContractState, list_id: u64, values: Span<felt252>
        ) {
            self.admin_role._assert_only_admin();
            self.trait_catalog.append_batch_to_trait_list(list_id, values);
        }

        fn ammend_trait_list(
            ref self: ContractState, list_id: u64, index: felt252, value: felt252
        ) {
            self.admin_role._assert_only_admin();
            self.trait_catalog.ammend_trait_list(list_id, index, value);
        }
    }
}
