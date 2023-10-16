#[starknet::contract]
mod SPillSystemRegistry {
    use starkpill::components::roles::admin::AdminRoleComponent::AdminRoleInternalTrait;
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address, get_contract_address};
    use souk::systems::utils::SystemInfo;
    use starkpill::components::upgradeable::UpgradeableComponent;
    use seraphlabs::tokens::src5::SRC5Component;
    use starkpill::components::access::AccessControlComponent;
    use starkpill::components::roles::AdminRoleComponent;
    use souk::systems::SoukSysRegComponent;
    use SoukSysRegComponent::{SoukSysRegInitializerImpl, ISoukSysRegImpl};
    use AccessControlComponent::{AccessControlInitializerImpl};
    use AdminRoleComponent::{AdminRoleInitializerImpl, AdminRoleInternalImpl};

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: AdminRoleComponent, storage: admin_role, event: AdminRoleEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: SoukSysRegComponent, storage: souk_reg, event: SoukSysRegEvent);

    #[abi(embed_v0)]
    impl AccessControl = AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5 = SRC5Component::SRC5Impl<ContractState>;

    #[abi(embed_v0)]
    impl Upgradeable = UpgradeableComponent::UpgradeableImpl<ContractState>;
    // -------------------------------------------------------------------------- //
    //                                   Storage                                  //
    // -------------------------------------------------------------------------- //

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        admin_role: AdminRoleComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        souk_reg: SoukSysRegComponent::Storage,
    }

    // -------------------------------------------------------------------------- //
    //                                   Events                                   //
    // -------------------------------------------------------------------------- //

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        UpgradeableEvent: UpgradeableComponent::Event,
        AccessControlEvent: AccessControlComponent::Event,
        AdminRoleEvent: AdminRoleComponent::Event,
        SRC5Event: SRC5Component::Event,
        SoukSysRegEvent: SoukSysRegComponent::Event,
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
        self.souk_reg.initializer();
    }

    // -------------------------------------------------------------------------- //
    //                       SPill System Registry Functions                      //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    #[external(v0)]
    impl SPillSysRegImpl of SPillSysRegTrait {
        fn total_systems(self: @ContractState) -> u128 {
            self.souk_reg.total_systems()
        }

        fn total_system_versions(self: @ContractState, system_id: u128) -> u64 {
            self.souk_reg.total_system_versions(system_id)
        }

        fn get_system(self: @ContractState, system_id: u128, version: u64) -> ClassHash {
            self.souk_reg.get_system(system_id, version)
        }

        fn inspect_system(self: @ContractState, system_class_hash: ClassHash) -> SystemInfo {
            self.souk_reg.inspect_system(system_class_hash)
        }

        fn register_system(ref self: ContractState, system_class_hash: ClassHash) -> u128 {
            self.admin_role._assert_only_admin();
            self.souk_reg.register_system(system_class_hash)
        }

        fn upgrade_system(ref self: ContractState, system_id: u128, system_class_hash: ClassHash) {
            self.admin_role._assert_only_admin();
            self.souk_reg.upgrade_system(system_id, system_class_hash);
        }
    }
}
