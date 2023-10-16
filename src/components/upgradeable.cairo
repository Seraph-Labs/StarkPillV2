use starknet::ClassHash;

#[starknet::interface]
trait IUpgradeable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::component]
mod UpgradeableComponent {
    use super::ClassHash;
    use starkpill::components::access::AccessControlComponent;
    use starkpill::components::roles::AdminRoleComponent;
    use AdminRoleComponent::AdminRoleInternalImpl;

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        Upgraded: Upgraded
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct Upgraded {
        class_hash: ClassHash
    }

    // -------------------------------------------------------------------------- //
    //                                  Embedable                                 //
    // -------------------------------------------------------------------------- //

    #[embeddable_as(UpgradeableImpl)]
    impl Upgradeable<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +AdminRoleComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IUpgradeable<ComponentState<TContractState>> {
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            IUpgradeableImpl::upgrade(ref self, new_class_hash);
        }
    }


    // -------------------------------------------------------------------------- //
    //                                  External                                  //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl IUpgradeableImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +AdminRoleComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IUpgradeableImplTrait<TContractState> {
        #[inline(always)]
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            let mut admin_role = self.get_admin_role_mut();
            admin_role._assert_only_admin();
            self._upgrade(new_class_hash);
        }
    }

    // -------------------------------------------------------------------------- //
    //                                  Internal                                  //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl UpgradeableInternalImpl<
        TContractState, +HasComponent<TContractState>,
    > of UpgradeableInternalTrait<TContractState> {
        #[inline(always)]
        fn _upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            assert(!new_class_hash.is_zero(), 'Class hash cannot be zero');
            starknet::replace_class_syscall(new_class_hash).unwrap();
            self.emit(Upgraded { class_hash: new_class_hash });
        }
    }

    // -------------------------------------------------------------------------- //
    //                                Dependencies                                //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl GetAdminRole<
        TContractState,
        +HasComponent<TContractState>,
        +AdminRoleComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetAdminRoleTrait<TContractState> {
        #[inline(always)]
        fn get_role_admin(
            self: @ComponentState<TContractState>
        ) -> @AdminRoleComponent::ComponentState<TContractState> {
            let contract = self.get_contract();
            AdminRoleComponent::HasComponent::<TContractState>::get_component(contract)
        }

        #[inline(always)]
        fn get_admin_role_mut(
            ref self: ComponentState<TContractState>
        ) -> AdminRoleComponent::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            AdminRoleComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
