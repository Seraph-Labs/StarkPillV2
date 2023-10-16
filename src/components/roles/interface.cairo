use starknet::ContractAddress;

#[starknet::interface]
trait IAdminRole<TContractState> {
    fn grant_admin_role(ref self: TContractState, account: ContractAddress);
    fn revoke_admin_role(ref self: TContractState, account: ContractAddress);
}
