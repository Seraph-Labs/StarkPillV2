#[starknet::component]
mod AccessControlComponent {
    use core::zeroable::Zeroable;
    use starkpill::components::access::interface;
    use starkpill::constants;
    use seraphlabs::tokens::src5::SRC5Component;
    use SRC5Component::SRC5InternalImpl;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    const ADMIN_ROLE: felt252 = 'ADMIN_ROLE';

    mod Errors {
        const INVALID_RENOUNCE: felt252 = 'Can only renounce role for self';
        const INVALID_REVOKE: felt252 = 'Cant revoke role from self';
        const MISSING_ROLE: felt252 = 'Caller is missing role';
    }

    #[storage]
    struct Storage {
        AccessControl_role_admin: LegacyMap<felt252, felt252>,
        AccessControl_role_member: LegacyMap<(felt252, ContractAddress), bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        RoleGranted: RoleGranted,
        RoleRevoked: RoleRevoked,
        RoleAdminChanged: RoleAdminChanged,
    }

    /// Emitted when `account` is granted `role`.
    ///
    /// `sender` is the account that originated the contract call, an admin role
    /// bearer (except if `_grant_role` is called during initialization from the constructor).
    #[derive(Drop, PartialEq, starknet::Event)]
    struct RoleGranted {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    }

    /// Emitted when `account` is revoked `role`.
    ///
    /// `sender` is the account that originated the contract call:
    ///   - If using `revoke_role`, it is the admin role bearer.
    ///   - If using `renounce_role`, it is the role bearer (i.e. `account`).
    #[derive(Drop, PartialEq, starknet::Event)]
    struct RoleRevoked {
        role: felt252,
        account: ContractAddress,
        sender: ContractAddress
    }

    /// Emitted when `new_admin_role` is set as `role`'s admin role, replacing `previous_admin_role`
    ///
    /// `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
    /// {RoleAdminChanged} not being emitted signaling this.
    #[derive(Drop, PartialEq, starknet::Event)]
    struct RoleAdminChanged {
        role: felt252,
        previous_admin_role: felt252,
        new_admin_role: felt252
    }

    // -------------------------------------------------------------------------- //
    //                               For Embeddable                               //
    // -------------------------------------------------------------------------- //
    #[embeddable_as(AccessControlImpl)]
    impl AccessControl<
        TContractState, +HasComponent<TContractState>,
    > of interface::IAccessControl<ComponentState<TContractState>> {
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            IAccessControlImpl::has_role(self, role, account)
        }

        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            IAccessControlImpl::get_role_admin(self, role)
        }

        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            IAccessControlImpl::grant_role(ref self, role, account);
        }

        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            IAccessControlImpl::revoke_role(ref self, role, account);
        }

        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            IAccessControlImpl::renounce_role(ref self, role, account);
        }
    }

    // -------------------------------------------------------------------------- //
    //                                 Initializer                                //
    // -------------------------------------------------------------------------- //
    #[generate_trait]
    impl AccessControlInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of AccessControlInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, admin: ContractAddress) {
            let mut src5 = self.get_src5_mut();
            src5.register_interface(constants::IACCESSCONTROL_ID);
            // emits 1 RoleGranted event
            self._grant_role(constants::DEFAULT_ADMIN_ROLE, admin);
        }
    }
    // -------------------------------------------------------------------------- //
    //                             External Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl IAccessControlImpl<
        TContractState, +HasComponent<TContractState>,
    > of IAccessControlImplTrait<TContractState> {
        #[inline(always)]
        fn has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self._has_role(role, account)
        }

        #[inline(always)]
        fn get_role_admin(self: @ComponentState<TContractState>, role: felt252) -> felt252 {
            self.AccessControl_role_admin.read(role)
        }

        #[inline(always)]
        fn grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let admin = self.AccessControl_role_admin.read(role);
            self._assert_only_role(admin);
            self._grant_role(role, account);
        }

        #[inline(always)]
        fn revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let admin = self.AccessControl_role_admin.read(role);
            let caller: ContractAddress = get_caller_address();
            assert(caller != account, Errors::INVALID_REVOKE);
            self._assert_only_role(admin);
            self._revoke_role(role, account);
        }

        #[inline(always)]
        fn renounce_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            let caller: ContractAddress = get_caller_address();
            assert(caller.is_non_zero(), 'Invalid Caller');
            assert(caller == account, Errors::INVALID_RENOUNCE);
            self._revoke_role(role, account);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             Internal Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl AccessControlInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of AccessControlInternalTrait<TContractState> {
        #[inline(always)]
        fn _has_role(
            self: @ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) -> bool {
            self.AccessControl_role_member.read((role, account))
        }

        #[inline(always)]
        fn _assert_only_role(self: @ComponentState<TContractState>, role: felt252) {
            let caller: ContractAddress = get_caller_address();
            assert(caller.is_non_zero(), 'Invalid Caller');
            let authorized: bool = self._has_role(role, caller);
            assert(authorized, Errors::MISSING_ROLE);
        }

        #[inline(always)]
        fn _grant_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            if !self._has_role(role, account) {
                let caller: ContractAddress = get_caller_address();
                self.AccessControl_role_member.write((role, account), true);
                self.emit(RoleGranted { role, account, sender: caller });
            }
        }

        #[inline(always)]
        fn _revoke_role(
            ref self: ComponentState<TContractState>, role: felt252, account: ContractAddress
        ) {
            if self._has_role(role, account) {
                let caller: ContractAddress = get_caller_address();
                self.AccessControl_role_member.write((role, account), false);
                self.emit(RoleRevoked { role, account, sender: caller });
            }
        }

        #[inline(always)]
        fn _set_role_admin(
            ref self: ComponentState<TContractState>, role: felt252, admin_role: felt252
        ) {
            let previous_admin_role: felt252 = self.AccessControl_role_admin.read(role);
            self.AccessControl_role_admin.write(role, admin_role);
            self.emit(RoleAdminChanged { role, previous_admin_role, new_admin_role: admin_role });
        }
    }


    // -------------------------------------------------------------------------- //
    //                              Get Dependencies                              //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl GetSRC5<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetSRC5Trait<TContractState> {
        #[inline(always)]
        fn get_src5(
            self: @ComponentState<TContractState>
        ) -> @SRC5Component::ComponentState<TContractState> {
            let contract = self.get_contract();
            SRC5Component::HasComponent::<TContractState>::get_component(contract)
        }

        #[inline(always)]
        fn get_src5_mut(
            ref self: ComponentState<TContractState>
        ) -> SRC5Component::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            SRC5Component::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
