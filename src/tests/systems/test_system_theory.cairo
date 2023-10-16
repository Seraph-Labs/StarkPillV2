use seraphlabs::utils::testing::{vars, helper};
use starknet::ContractAddress;
use starknet::ClassHash;
use starknet::{get_caller_address, get_contract_address};
use starknet::testing::{set_caller_address, set_contract_address, pop_log, pop_log_raw};
use starknet::library_call_syscall;
use debug::PrintTrait;

mod Selectors {
    const INITIALIZER: felt252 = selector!("initializer");
    const GET_DIFF_ARG: felt252 = selector!("get_diff_arg");
    const GET_DIFF_ARG_2: felt252 = selector!("get_diff_arg_2");
    const ADD_SYSTEM: felt252 = selector!("add_system");
    const CHANGE_ARG: felt252 = selector!("change_arg");
    const GET_CALLER: felt252 = selector!("get_caller");
    const GET_CONTRACT: felt252 = selector!("get_contract");
}

#[starknet::interface]
trait IMockTerm<TContractState> {
    fn get_arg(self: @TContractState, index: u256) -> felt252;
    fn edit_arg(ref self: TContractState, index: u256, value: felt252);
    fn add_system(ref self: TContractState, system: ClassHash, system_calldata: Array<felt252>);
    fn execute_system(
        ref self: TContractState,
        system: ClassHash,
        selector: felt252,
        system_calldata: Array<felt252>
    ) -> Span<felt252>;
}

#[starknet::contract]
mod MockTerm {
    use super::{ContractAddress, ClassHash};
    use super::Selectors;
    use super::library_call_syscall;
    use super::IMockTerm;

    #[storage]
    struct Storage {
        counter: u256,
        same_arg: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ArgChanged: ArgChanged,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ArgChanged {
        #[key]
        index: u256,
        old_value: felt252,
        new_value: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[external(v0)]
    impl IMockTermImpl of IMockTerm<ContractState> {
        fn get_arg(self: @ContractState, index: u256) -> felt252 {
            self.same_arg.read(index)
        }

        fn edit_arg(ref self: ContractState, index: u256, value: felt252) {
            let old_value = self.same_arg.read(index);
            self.same_arg.write(index, value);
            self.emit(ArgChanged { index, old_value, new_value: value });
        }

        fn add_system(ref self: ContractState, system: ClassHash, system_calldata: Array<felt252>) {
            library_call_syscall(system, Selectors::INITIALIZER, system_calldata.span()).unwrap();
        }

        fn execute_system(
            ref self: ContractState,
            system: ClassHash,
            selector: felt252,
            system_calldata: Array<felt252>
        ) -> Span<felt252> {
            library_call_syscall(system, selector, system_calldata.span()).unwrap()
        }
    }
}

#[starknet::contract]
mod MockSystem {
    use super::{ContractAddress, ClassHash};
    use super::{get_caller_address, get_contract_address};
    use super::library_call_syscall;
    use super::Selectors;

    #[storage]
    struct Storage {
        same_arg: LegacyMap<u256, felt252>,
        system: ClassHash,
        diff_arg: u256,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ArgChanged: ArgChanged,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct ArgChanged {
        #[key]
        index: u256,
        old_value: felt252,
        new_value: felt252,
    }

    #[generate_trait]
    #[external(v0)]
    impl IMockSystemImpl of IMockSystemTrait {
        fn initializer(ref self: ContractState, x: u256) {
            self.diff_arg.write(x);
        }

        fn get_diff_arg(self: @ContractState) -> u256 {
            self.diff_arg.read()
        }

        fn get_diff_arg_2(self: @ContractState) -> felt252 {
            let system = self.system.read();
            let mut system_calldata = ArrayTrait::new();
            let mut ret = library_call_syscall(
                system, Selectors::GET_DIFF_ARG_2, system_calldata.span()
            )
                .unwrap();
            Serde::<felt252>::deserialize(ref ret).unwrap()
        }

        fn add_system(ref self: ContractState, system: ClassHash, system_calldata: Array<felt252>) {
            self.system.write(system);
            library_call_syscall(system, Selectors::INITIALIZER, system_calldata.span()).unwrap();
        }


        fn change_arg(ref self: ContractState, index: u256, value: felt252) {
            let old_value = self.same_arg.read(index);
            self.same_arg.write(index, value);
            self.emit(ArgChanged { index, old_value, new_value: value });
        }

        fn get_caller(self: @ContractState) -> ContractAddress {
            get_caller_address()
        }

        fn get_contract(self: @ContractState) -> ContractAddress {
            get_contract_address()
        }
    }
}

#[starknet::contract]
mod MockSystem2 {
    use super::{ContractAddress, ClassHash};
    use super::{get_caller_address, get_contract_address};
    #[storage]
    struct Storage {
        diff_arg_2: felt252
    }

    #[generate_trait]
    #[external(v0)]
    impl IMockSystemImpl of IMockSystemTrait {
        fn initializer(ref self: ContractState, x: felt252) {
            self.diff_arg_2.write(x);
        }

        fn get_diff_arg_2(self: @ContractState) -> felt252 {
            self.diff_arg_2.read()
        }
    }
}


fn setup() -> ContractAddress {
    let mut calldata = ArrayTrait::new();
    helper::deploy(MockTerm::TEST_CLASS_HASH, calldata)
}


#[test]
#[available_gas(2000000)]
fn test_serialization() {
    let mut data = ArrayTrait::new();
    let arg1 = 10_u32;
    let arg2 = 115792089237316195423570985008687907853269984665640564039457584007913129639935_u256;
    let arg3 = 0_felt252;
    let arg4 = array![1_u8, 2_u8, 3_u8];
    let arg5 = 200_felt252;
    let arg6 = vars::OWNER();
    let arg7 = false;

    Serde::serialize(@arg1, ref data);
    Serde::serialize(@arg2, ref data);
    Serde::serialize(@arg3, ref data);
    Serde::serialize(@arg4, ref data);
    Serde::serialize(@arg5, ref data);
    Serde::serialize(@arg6, ref data);
    Serde::serialize(@arg7, ref data);

    let mut data_span = data.span();
    let el1 = Serde::<u32>::deserialize(ref data_span).unwrap();
    let el2 = Serde::<u256>::deserialize(ref data_span).unwrap();
    let el3 = Serde::<felt252>::deserialize(ref data_span).unwrap();
    let el4 = Serde::<Array<u8>>::deserialize(ref data_span).unwrap();
    let el5 = Serde::<felt252>::deserialize(ref data_span).unwrap();
    let el6 = Serde::<ContractAddress>::deserialize(ref data_span).unwrap();
    let el7 = Serde::<bool>::deserialize(ref data_span).unwrap();

    assert(el1 == arg1, 'el1 deserialization failed');
    assert(el2 == arg2, 'el2 deserialization failed');
    assert(el3 == arg3, 'el3 deserialization failed');
    assert(el4 == arg4, 'el4 deserialization failed');
    assert(el5 == arg5, 'el5 deserialization failed');
    assert(el6 == arg6, 'el6 deserialization failed');
    assert(el7 == arg7, 'el7 deserialization failed');
}

#[test]
#[available_gas(2000000000)]
fn test_system_execution() {
    let mock_address = setup();
    let mock = IMockTermDispatcher { contract_address: mock_address };
    let mock_system_class_hash: ClassHash = MockSystem::TEST_CLASS_HASH.try_into().unwrap();
    let mock_system_class_hash_2: ClassHash = MockSystem2::TEST_CLASS_HASH.try_into().unwrap();
    let owner = vars::OWNER();

    mock.edit_arg(0, 10);
    assert(mock.get_arg(0) == 10, 'get_arg failed');

    // test initialization
    let mut system_calldata_1 = ArrayTrait::new();
    Serde::serialize(@20_u256, ref system_calldata_1);
    mock.add_system(mock_system_class_hash, system_calldata_1);
    let mut serialized_res1 = mock
        .execute_system(mock_system_class_hash, Selectors::GET_DIFF_ARG, array![]);
    let res1 = Serde::<u256>::deserialize(ref serialized_res1).unwrap();
    assert(res1 == 20, 'system execution failed');

    // test add new existing store
    let mut system_calldata_2 = ArrayTrait::new();
    Serde::serialize(@1_u256, ref system_calldata_2);
    Serde::serialize(@20, ref system_calldata_2);
    mock.execute_system(mock_system_class_hash, Selectors::CHANGE_ARG, system_calldata_2);
    assert(mock.get_arg(1) == 20, 'system execution failed');

    // test change existing store
    let mut system_calldata_3 = ArrayTrait::new();
    Serde::serialize(@0_u256, ref system_calldata_3);
    Serde::serialize(@30, ref system_calldata_3);
    mock.execute_system(mock_system_class_hash, Selectors::CHANGE_ARG, system_calldata_3);
    assert(mock.get_arg(0) == 30, 'system execution failed');

    // test internal lib call
    let mut system_calldata_4 = ArrayTrait::new();
    Serde::serialize(@mock_system_class_hash_2, ref system_calldata_4);
    Serde::serialize(@array![2114], ref system_calldata_4);
    mock.execute_system(mock_system_class_hash, Selectors::ADD_SYSTEM, system_calldata_4);
    let mut serialized_res2 = mock
        .execute_system(mock_system_class_hash, Selectors::GET_DIFF_ARG_2, array![]);
    assert(
        Serde::<felt252>::deserialize(ref serialized_res2).unwrap() == 2114,
        'system execution failed'
    );

    // test address
    set_contract_address(owner);
    let mut serialized_res3 = mock
        .execute_system(mock_system_class_hash, Selectors::GET_CALLER, array![]);
    let res3 = Serde::<ContractAddress>::deserialize(ref serialized_res3).unwrap();
    assert(res3 == owner, 'system execution failed');

    let mut serialized_res4 = mock
        .execute_system(mock_system_class_hash, Selectors::GET_CONTRACT, array![]);
    let res4 = Serde::<ContractAddress>::deserialize(ref serialized_res4).unwrap();
    assert(res4 == mock_address, 'system execution failed');
    // test events
    assert_arg_changed_event(mock_address, 0, 0, 10);
    assert_arg_changed_event(mock_address, 1, 0, 20);
    assert_arg_changed_event(mock_address, 0, 10, 30);
    helper::assert_no_events_left(mock_address);
}

fn assert_arg_changed_event(
    contract_addr: ContractAddress, index: u256, old_value: felt252, new_value: felt252
) {
    let event = pop_log::<MockTerm::Event>(contract_addr).unwrap();
    assert(
        event == MockTerm::Event::ArgChanged(MockTerm::ArgChanged { index, old_value, new_value }),
        'Wrong Event'
    );
}
