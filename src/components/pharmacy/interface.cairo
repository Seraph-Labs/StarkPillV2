use starknet::ContractAddress;

#[starknet::interface]
trait IPharmacy<TContractState> {
    fn get_stock(self: @TContractState, attr_id: u64, index: felt252) -> (u128, u128);
    fn get_eth_premium(self: @TContractState, attr_id: u64, index: felt252) -> u256;
    fn update_stock(ref self: TContractState, attr_id: u64, index: felt252, ammount: u128);
    fn update_premium(ref self: TContractState, attr_id: u64, index: felt252, ammount: u256);
    fn set_l2_project_redemtion(
        ref self: TContractState,
        project_address: ContractAddress,
        attr_id: u64,
        indexes: Span<felt252>,
        redeemable: bool
    );
}
