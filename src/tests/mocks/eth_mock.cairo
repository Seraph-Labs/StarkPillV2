use starknet::ContractAddress;

#[starknet::interface]
trait IERC20Mintable<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn symbol(self: @TContractState) -> felt252;
    fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    fn transfer_from(
        ref self: TContractState, sender: ContractAddress, recipient: ContractAddress, amount: u256
    ) -> bool;
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;
    fn mint(ref self: TContractState, recepient: ContractAddress, amount: u256);
}

#[starknet::contract]
mod EthMock {
    use super::ContractAddress;
    use starknet::get_caller_address;
    use starkpill::components::erc20::ERC20Component;
    use ERC20Component::{ERC20InitializerImpl, ERC20InternalImpl};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    #[abi(embed_v0)]
    impl ERC20 = ERC20Component::ERC20Impl<ContractState>;

    // -------------------------------------------------------------------------- //
    //                                   Storage                                  //
    // -------------------------------------------------------------------------- //

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
    }

    // -------------------------------------------------------------------------- //
    //                                   Events                                   //
    // -------------------------------------------------------------------------- //

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        ERC20Event: ERC20Component::Event,
    }

    // -------------------------------------------------------------------------- //
    //                                 Constructor                                //
    // -------------------------------------------------------------------------- //
    #[constructor]
    fn constructor(ref self: ContractState) {
        self.erc20.initializer('Ether', 'ETH');
    }

    // -------------------------------------------------------------------------- //
    //                                  Mintable                                  //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    #[external(v0)]
    impl ERC20MintImpl of ERC20MintTrait {
        fn mint(ref self: ContractState, recepient: ContractAddress, ammount: u256) {
            self.erc20._mint(recepient, ammount);
        }
    }
}
