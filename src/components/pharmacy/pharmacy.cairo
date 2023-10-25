#[starknet::component]
mod PharmacyComponent {
    use starknet::{ContractAddress, ClassHash};
    use starknet::get_caller_address;
    use starkpill::constants;
    use starkpill::components::pharmacy::interface;
    use seraphlabs::tokens::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    use starkpill::components::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starkpill::components::pharmacy::utils::{PharmacyStock, PharmacyStockTrait};
    use starkpill::components::access::AccessControlComponent;
    use starkpill::components::roles::AdminRoleComponent;
    use AdminRoleComponent::AdminRoleInternalImpl;

    #[storage]
    struct Storage {
        spill_pharmacy_stock: LegacyMap<(u64, felt252), PharmacyStock>,
        spill_pharmacy_eth_premium: LegacyMap<(u64, felt252), u256>,
        spill_pharmacy_currency: LegacyMap<u64, ContractAddress>,
        spill_pharmacy_bank: LegacyMap<u64, ContractAddress>,
        spill_pharmacy_l2_redeemable: LegacyMap<(ContractAddress, u64, felt252), bool>,
        spill_pharmacy_l2_claims: LegacyMap<(ContractAddress, u256), bool>,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        PharmacyStockUpdate: PharmacyStockUpdate,
        PharmacyPremium: PharmacyPremium,
        PharmacyL2Redemption: PharmacyL2Redemption,
        PharmacyL2RedemptionApproval: PharmacyL2RedemptionApproval,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PharmacyStockUpdate {
        #[key]
        attr_id: u64,
        #[key]
        index: felt252,
        numerator: u128,
        denominator: u128
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PharmacyPremium {
        #[key]
        attr_id: u64,
        #[key]
        index: felt252,
        #[key]
        currency: ContractAddress,
        ammount: u256,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PharmacyL2Redemption {
        #[key]
        project_address: ContractAddress,
        #[key]
        token_id: u256,
        #[key]
        received_token_id: u256,
        #[key]
        to: ContractAddress,
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    struct PharmacyL2RedemptionApproval {
        #[key]
        project_address: ContractAddress,
        #[key]
        attr_id: u64,
        #[key]
        index: felt252,
        #[key]
        approved: bool,
    }

    // -------------------------------------------------------------------------- //
    //                                 Embeddable                                 //
    // -------------------------------------------------------------------------- //

    #[embeddable_as(PharmacyImpl)]
    impl Pharmacy<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +AdminRoleComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IPharmacy<ComponentState<TContractState>> {
        fn get_stock(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> (u128, u128) {
            IPharmacyImpl::get_stock(self, attr_id, index)
        }

        fn get_eth_premium(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> u256 {
            IPharmacyImpl::get_eth_premium(self, attr_id, index)
        }

        fn get_pharmacy_addresses(
            self: @ComponentState<TContractState>, currency: bool, index: u64
        ) -> ContractAddress {
            IPharmacyImpl::get_pharmacy_addresses(self, currency, index)
        }

        fn l2_reedemtion_approval(
            self: @ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            index: felt252
        ) -> bool {
            IPharmacyImpl::l2_reedemtion_approval(self, project_address, attr_id, index)
        }

        fn update_stock(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, ammount: u128
        ) {
            IPharmacyImpl::update_stock(ref self, attr_id, index, ammount);
        }

        fn update_premium(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, ammount: u256
        ) {
            IPharmacyImpl::update_premium(ref self, attr_id, index, ammount);
        }

        fn set_l2_project_redemtion(
            ref self: ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            indexes: Span<felt252>,
            redeemable: bool
        ) {
            IPharmacyImpl::set_l2_project_redemtion(
                ref self, project_address, attr_id, indexes, redeemable
            );
        }
    }

    // -------------------------------------------------------------------------- //
    //                                 Initializer                                //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl PharmacyInitializerImpl<
        TContractState, +HasComponent<TContractState>,
    > of PharmacyInitializerTrait<TContractState> {
        #[inline(always)]
        fn initializer(
            ref self: ComponentState<TContractState>,
            eth_currency: ContractAddress,
            wallet: ContractAddress,
            price: u256
        ) {
            // set eth currency
            self._set_pharmacy_eth_currency(eth_currency);
            // set wallet
            self._set_pharmacy_bank_address(wallet);
            // set base mint price
            // @dev emits 1 PharmacyPremium event
            self._set_pharmacy_pill_base_price(price);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             External Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl IPharmacyImpl<
        TContractState,
        +HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        +AdminRoleComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IPharmacyImplTrait<TContractState> {
        #[inline(always)]
        fn get_stock(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> (u128, u128) {
            self._get_stock(attr_id, index)
        }

        #[inline(always)]
        fn get_eth_premium(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> u256 {
            self._get_eth_premium(attr_id, index)
        }

        #[inline(always)]
        fn get_pharmacy_addresses(
            self: @ComponentState<TContractState>, currency: bool, index: u64
        ) -> ContractAddress {
            match currency {
                bool::False => self.spill_pharmacy_bank.read(index),
                bool::True => self.spill_pharmacy_currency.read(index),
            }
        }

        #[inline(always)]
        fn l2_reedemtion_approval(
            self: @ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            index: felt252
        ) -> bool {
            self.spill_pharmacy_l2_redeemable.read((project_address, attr_id, index))
        }

        #[inline(always)]
        fn update_stock(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, ammount: u128
        ) {
            let mut admin_role = self.get_admin_role_mut();
            admin_role._assert_only_admin();
            // if ammount is zero means clear stock
            let mut stock: PharmacyStock = self.spill_pharmacy_stock.read((attr_id, index));
            match ammount.is_zero() {
                bool::False => { stock.add_stock(ammount); },
                bool::True => {
                    // this function sets stock to zero and already checks if stock is already zero
                    stock.reset_stock();
                }
            };

            // update stock
            self._update_pharmacy_stock(attr_id, index, stock);
        }

        #[inline(always)]
        fn update_premium(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, ammount: u256
        ) {
            let mut admin_role = self.get_admin_role_mut();
            admin_role._assert_only_admin();
            // update premium
            self._update_pharmacy_eth_premium(attr_id, index, ammount);
        }

        #[inline(always)]
        fn set_l2_project_redemtion(
            ref self: ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            indexes: Span<felt252>,
            redeemable: bool
        ) {
            let mut admin_role = self.get_admin_role_mut();
            admin_role._assert_only_admin();
            // this function emits event
            self._set_l2_project_redemptiom(project_address, attr_id, indexes, redeemable);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             Internal Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl PharmacyInternalImpl<
        TContractState, +HasComponent<TContractState>
    > of PharmacyInternalTrait<TContractState> {
        #[inline(always)]
        fn _assert_not_redemption_only(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) {
            let is_only_redeemable = self
                .spill_pharmacy_l2_redeemable
                .read((Zeroable::zero(), attr_id, index));
            assert(!is_only_redeemable, 'SPill: only redemption');
        }

        #[inline(always)]
        fn _assert_has_not_been_claimed(
            self: @ComponentState<TContractState>, project_address: ContractAddress, token_id: u256
        ) {
            let claimed = self.spill_pharmacy_l2_claims.read((project_address, token_id));
            assert(!claimed, 'SPill: token already claimed');
        }

        #[inline(always)]
        fn _assert_reedemable(
            self: @ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            index: felt252
        ) {
            let is_redeemable = self
                .spill_pharmacy_l2_redeemable
                .read((project_address, attr_id, index));
            assert(is_redeemable, 'SPill: not redeemable');
        }

        #[inline(always)]
        fn _get_stock(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> (u128, u128) {
            let stock: PharmacyStock = self.spill_pharmacy_stock.read((attr_id, index));
            (stock.numerator, stock.denominator)
        }

        #[inline(always)]
        fn _get_eth_premium(
            self: @ComponentState<TContractState>, attr_id: u64, index: felt252
        ) -> u256 {
            self.spill_pharmacy_eth_premium.read((attr_id, index))
        }

        // @dev pill total cost is just the base cost of having the name attribute set to pill
        #[inline(always)]
        fn _get_pill_eth_total_cost(self: @ComponentState<TContractState>, index: felt252) -> u256 {
            if index.is_zero() {
                return 0;
            }
            // pill base price
            self.spill_pharmacy_eth_premium.read((constants::NAME_ID, 1))
        }

        // @dev ingredient total cost is the base cost which is name attribute set to ingredient (should cost 0)
        //  plus the premium to get the ingredient attribute set to the given index
        #[inline(always)]
        fn _get_ing_eth_total_cost(self: @ComponentState<TContractState>, index: felt252) -> u256 {
            if index.is_zero() {
                return 0;
            }
            let base_price = self.spill_pharmacy_eth_premium.read((constants::NAME_ID, 2));
            let premium = self.spill_pharmacy_eth_premium.read((constants::ING_ID, index));
            base_price + premium
        }

        // @dev background total cost is the base cost which is name attribute set to background (should cost 0)
        //  plus the premium to get the background attribute set to the given index
        #[inline(always)]
        fn _get_bg_eth_total_cost(self: @ComponentState<TContractState>, index: felt252) -> u256 {
            if index.is_zero() {
                return 0;
            }
            let base_price = self.spill_pharmacy_eth_premium.read((constants::NAME_ID, 3));
            let premium = self.spill_pharmacy_eth_premium.read((constants::BG_ID, index));
            base_price + premium
        }

        // @dev updates l2 project redemption status
        // DOES check if indexes are non zero
        // DOES check if status is already same 
        // is project address is zero sets attribute as only redeemable
        // EMITS PharmacyL2RedemptionApproval event
        fn _set_l2_project_redemptiom(
            ref self: ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            indexes: Span<felt252>,
            redeemable: bool
        ) {
            let mut index_arr = indexes;
            loop {
                match index_arr.pop_front() {
                    Option::Some(i) => {
                        let index = *i;
                        assert(index.is_non_zero(), 'SPill: invalid trait index');
                        // assert cur_status is not the same
                        let cur_status = self
                            .spill_pharmacy_l2_redeemable
                            .read((project_address, attr_id, index));
                        assert(cur_status != redeemable, 'SPill: redeemable already set');
                        // this functions updates approval and emits event
                        self
                            ._update_l2_redemption_approval(
                                project_address, attr_id, index, redeemable
                            );
                    },
                    Option::None(_) => { break; }
                };
            };
        }

        // @dev this function sets a token_id of a given project as claimed
        // DOES check if the token id is valid
        // DOES NOT check if the token id is already claimed
        // DOES NOT check if the reveived token id is valid
        // DOES NOT mint token
        // DOES NOT check if the project address is valid
        // DOES check if caller is approved
        // EMITS PharmacyL2Redemption event
        #[inline(always)]
        fn _redeem_l2_project(
            ref self: ComponentState<TContractState>,
            project_address: ContractAddress,
            token_id: u256,
            received_token_id: u256,
            to: ContractAddress
        ) {
            assert(token_id.is_non_zero(), 'SPill: invalid token id');
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'SPill: zero caller');

            let erc721 = IERC721Dispatcher { contract_address: project_address };
            let owner = erc721.owner_of(token_id);
            let approved = erc721.get_approved(token_id);
            let is_approved_all = erc721.is_approved_for_all(owner, caller);
            // assert caller is owner or approved
            assert(
                owner == caller || approved == caller || is_approved_all,
                'SPill: caller not approved'
            );
            // set claims for token id to be true
            self.spill_pharmacy_l2_claims.write((project_address, token_id), true);
            // emit event
            self.emit(PharmacyL2Redemption { project_address, token_id, received_token_id, to });
        }

        // @dev transfer callers eth to the pharmacy wallet
        //  DOES check if there is enough eth
        //  DOES check validity of wallet and currency address
        //  DOES not check validity of spender address
        //  DOES not check validity of item that is bought
        // @return the the total eth spent on pill including tips, for pills medical bill trait
        //  which is `price` - ing_total_cost - bg_total_cost
        #[inline(always)]
        fn _pharmacy_eth_purchase(
            ref self: ComponentState<TContractState>,
            spender: ContractAddress,
            pill: felt252,
            ing: felt252,
            bg: felt252,
            price: u256
        ) -> u256 {
            let pill_price = self._get_pill_eth_total_cost(pill);
            let ing_price = self._get_ing_eth_total_cost(ing);
            let bg_price = self._get_bg_eth_total_cost(bg);
            let total_trait_cost = ing_price + bg_price;
            let total_cost = pill_price + total_trait_cost;
            // assert price is not lower than the total cost
            assert(price >= total_cost, 'SPill: minimum price not met');
            // get price spent on pill
            let pill_mbill = price - total_trait_cost;
            if price.is_zero() {
                return pill_mbill;
            }
            // if not try and purchase with eth
            let currency = self._get_pharmacy_eth_currency();
            let wallet = self._get_pharmacy_bank_address();
            let eth = IERC20Dispatcher { contract_address: currency };
            assert(eth.balance_of(spender) >= price, 'SPill: not enough eth');

            // transfer erh
            let success = eth.transfer_from(spender, wallet, price);
            assert(success, 'SPill: eth transfer failed');
            pill_mbill
        }

        // @dev sells a stock of a given slot and index
        //  DOES check if there is stock to sell
        //  if stock is infinite return
        //  EMITS PharmacyStockUpdate event
        #[inline(always)]
        fn _clear_pharmacy_stock(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252
        ) {
            let mut stock = self.spill_pharmacy_stock.read((attr_id, index));
            // this function already checks if there is stock to sell
            // if stock is infinite return
            let is_sold = stock.sell_stock();
            if is_sold {
                self._update_pharmacy_stock(attr_id, index, stock);
            }
        }
    }

    // -------------------------------------------------------------------------- //
    //                              Private Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl PharmacyPrivateImpl<
        TContractState, +HasComponent<TContractState>
    > of PharmacyPrivateTrait<TContractState> {
        #[inline(always)]
        fn _get_pharmacy_bank_address(self: @ComponentState<TContractState>) -> ContractAddress {
            let res = self.spill_pharmacy_bank.read(0);
            assert(res.is_non_zero(), 'SPill: wallet not set');
            res
        }

        #[inline(always)]
        fn _get_pharmacy_eth_currency(self: @ComponentState<TContractState>) -> ContractAddress {
            let res = self.spill_pharmacy_currency.read(0);
            assert(res.is_non_zero(), 'SPill: eth currency not set');
            res
        }

        #[inline(always)]
        fn _set_pharmacy_bank_address(
            ref self: ComponentState<TContractState>, account: ContractAddress
        ) {
            self.spill_pharmacy_bank.write(0, account);
        }

        #[inline(always)]
        fn _set_pharmacy_eth_currency(
            ref self: ComponentState<TContractState>, currency: ContractAddress
        ) {
            self.spill_pharmacy_currency.write(0, currency);
        }

        #[inline(always)]
        fn _set_pharmacy_pill_base_price(ref self: ComponentState<TContractState>, ammount: u256) {
            self._update_pharmacy_eth_premium(constants::NAME_ID, 1, ammount);
        }

        // sets a attr_id and index as only redeemable
        // by setting the boolean to a zero adress that indicates for all
        #[inline(always)]
        fn _set_pharmacy_attribute_only_redeemable(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, redeemable: bool
        ) {
            assert(index.is_non_zero(), 'SPill: invalid trait index');
            let cur_status = self
                .spill_pharmacy_l2_redeemable
                .read((Zeroable::zero(), attr_id, index));
            if cur_status == redeemable {
                return;
            }
            self.spill_pharmacy_l2_redeemable.write((Zeroable::zero(), attr_id, index), redeemable);
        }

        // @dev updates approval 
        // emits PharmacyL2RedemptionApproval event
        #[inline(always)]
        fn _update_l2_redemption_approval(
            ref self: ComponentState<TContractState>,
            project_address: ContractAddress,
            attr_id: u64,
            index: felt252,
            approved: bool
        ) {
            self.spill_pharmacy_l2_redeemable.write((project_address, attr_id, index), approved);
            self.emit(PharmacyL2RedemptionApproval { project_address, attr_id, index, approved });
        }

        #[inline(always)]
        fn _update_pharmacy_eth_premium(
            ref self: ComponentState<TContractState>, attr_id: u64, index: felt252, ammount: u256
        ) {
            self.spill_pharmacy_eth_premium.write((attr_id, index), ammount);
            self
                .emit(
                    PharmacyPremium {
                        attr_id, index, currency: self._get_pharmacy_eth_currency(), ammount
                    }
                );
        }

        #[inline(always)]
        fn _update_pharmacy_stock(
            ref self: ComponentState<TContractState>,
            attr_id: u64,
            index: felt252,
            stock: PharmacyStock
        ) {
            self.spill_pharmacy_stock.write((attr_id, index), stock);
            self
                .emit(
                    PharmacyStockUpdate {
                        attr_id, index, numerator: stock.numerator, denominator: stock.denominator,
                    }
                );
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
        fn get_admin_role(
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
