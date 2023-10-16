#[starknet::component]
mod AdminRoleComponent {
    use starkpill::components::roles::interface;
    use starkpill::constants;
    use starkpill::components::access::AccessControlComponent;
    use AccessControlComponent::{IAccessControlImpl, AccessControlInternalImpl};
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {}

    // -------------------------------------------------------------------------- //
    //                               For Embeddable                               //
    // -------------------------------------------------------------------------- //
    #[embeddable_as(AdminRoleImpl)]
    impl AdminRole<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IAdminRole<ComponentState<TContractState>> {
        fn grant_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            IAdminRoleImpl::grant_admin_role(ref self, account);
        }

        fn revoke_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            IAdminRoleImpl::revoke_admin_role(ref self, account);
        }
    }
    // -------------------------------------------------------------------------- //
    //                                 Initalizer                                 //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl AdminRoleInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of AdminRoleInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            // emits 1 RoleGranted event
            self._grant_admin_role(admin);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             External Functions                             //
    // -------------------------------------------------------------------------- //
    #[generate_trait]
    impl IAdminRoleImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IAdminRoleImplTrait<TContractState> {
        #[inline(always)]
        fn grant_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = self.get_access_control_mut();
            access_control._assert_only_role(access_control.get_role_admin(constants::ADMIN_ROLE));
            self._grant_admin_role(account);
        }

        #[inline(always)]
        fn revoke_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = self.get_access_control_mut();
            access_control._assert_only_role(access_control.get_role_admin(constants::ADMIN_ROLE));
            self._revoke_admin_role(account);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             Internal Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl AdminRoleInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of AdminRoleInternalTrait<TContractState> {
        #[inline(always)]
        fn _assert_only_admin(self: @ComponentState<TContractState>) {
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'Invalid Caller');
            let authorized = self.get_access_control()._has_role(constants::ADMIN_ROLE, caller);
            assert(authorized, "caller not admin");
        }

        #[inline(always)]
        fn _grant_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = self.get_access_control_mut();
            access_control._grant_role(constants::ADMIN_ROLE, account);
        }

        #[inline(always)]
        fn _revoke_admin_role(ref self: ComponentState<TContractState>, account: ContractAddress) {
            let mut access_control = self.get_access_control_mut();
            access_control._revoke_role(constants::ADMIN_ROLE, account);
        }
    }

    // -------------------------------------------------------------------------- //
    //                              Get Dependencies                              //
    // -------------------------------------------------------------------------- //
    #[generate_trait]
    impl GetAccessControl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetAccessControlTrait<TContractState> {
        #[inline(always)]
        fn get_access_control(
            self: @ComponentState<TContractState>
        ) -> @AccessControlComponent::ComponentState<TContractState> {
            let contract = self.get_contract();
            AccessControlComponent::HasComponent::<TContractState>::get_component(contract)
        }

        #[inline(always)]
        fn get_access_control_mut(
            ref self: ComponentState<TContractState>
        ) -> AccessControlComponent::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            AccessControlComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
