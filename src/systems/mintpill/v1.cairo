#[starknet::contract]
mod MintPillSystem {
    use starknet::{ContractAddress, ClassHash};
    use starknet::{get_caller_address, get_contract_address};
    use souk::systems::interface;
    use seraphlabs::tokens::erc2114::utils::{AttrType, AttrTypeTrait};
    use seraphlabs::tokens::constants;
    use starkpill::constants as pill_constants;
    use starkpill::components::pharmacy::PharmacyComponent;
    // token components
    use seraphlabs::tokens::erc721::{ERC721Component, extensions::ERC721EnumComponent};
    use seraphlabs::tokens::erc3525::ERC3525Component;
    use seraphlabs::tokens::erc2114::{
        ERC2114Component, extensions::{ERC2114InvComponent, ERC2114SlotAttrComponent}
    };

    use PharmacyComponent::PharmacyInternalImpl;
    use ERC721EnumComponent::{IERC721EnumImpl, ERC721EnumInternalImpl};
    use ERC3525Component::{ERC3525InternalImpl, IERC3525Impl};
    use ERC2114Component::{ERC2114InternalImpl, ERC2114PrivateImpl};
    use ERC2114InvComponent::{ERC2114InvInternalImpl, ERC2114InvPrivateImpl};

    // pharmacy
    component!(path: PharmacyComponent, storage: pharmacy, event: PharmacyEvent);
    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721EnumComponent, storage: erc721_enum, event: ERC721EnumEvent);
    component!(path: ERC3525Component, storage: erc3525, event: ERC3525Event);
    component!(path: ERC2114Component, storage: erc2114, event: ERC2114Event);
    component!(path: ERC2114InvComponent, storage: erc2114_inv, event: ERC2114InvEvent);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        pharmacy: PharmacyComponent::Storage,
        // tokens
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enum: ERC721EnumComponent::Storage,
        #[substorage(v0)]
        erc3525: ERC3525Component::Storage,
        #[substorage(v0)]
        erc2114: ERC2114Component::Storage,
        #[substorage(v0)]
        erc2114_inv: ERC2114InvComponent::Storage,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {
        PharmacyEvent: PharmacyComponent::Event,
        ERC721Event: ERC721Component::Event,
        ERC721EnumEvent: ERC721EnumComponent::Event,
        ERC3525Event: ERC3525Component::Event,
        ERC2114Event: ERC2114Component::Event,
        ERC2114InvEvent: ERC2114InvComponent::Event,
    }

    #[external(v0)]
    impl MintPillSystemImpl of interface::ISoukSystem<ContractState> {
        fn name(self: @ContractState) -> felt252 {
            'Mint Pill V1'
        }

        fn author(self: @ContractState) -> felt252 {
            'kahi'
        }

        fn required_interfaces(self: @ContractState) -> Span<felt252> {
            array![
                constants::IERC721_ID,
                constants::IERC721_ENUMERABLE_ID,
                constants::IERC3525_ID,
                constants::IERC2114_ID,
                constants::IERC2114_INVENTORY_ID,
            ]
                .span()
        }

        fn system_uri(self: @ContractState) -> Array<felt252> {
            array!['starkpill mint pill function']
        }
    }

    #[generate_trait]
    #[external(v0)]
    impl MintPillSystemExecutableIImpl of MintPillSystemExecutableTrait {
        fn initializer(ref self: ContractState) {}

        fn execute(
            ref self: ContractState, to: ContractAddress, ing: felt252, bg: felt252, price: u256
        ) {
            // assert caller is not zero
            let caller = get_caller_address();
            assert(caller.is_non_zero(), 'caller is zero');

            // try and purchase with eth
            // this function already checks if caller has the eth to spend
            let pill_mbill: u256 = self.pharmacy._pharmacy_eth_purchase(caller, 1, ing, bg, price);
            // @dev mint pill
            //  EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
            //  EMITS 1 TokenAttributeUpdate event if mbill is not zero
            let pill_id: u256 = self._mint_pill(to, pill_mbill);
            // @dev mint ing 
            //  EMITS 1 PharmacyStockUpdate event if there is stock to sell 
            //  EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
            //  EMITS 1-2 TokenAttributeUpdate events
            //  EMITS 1 ScalarTransfer event
            //  EMITS 1 InventoryUpdate event
            self._mint_ing(to, pill_id, ing);
            // @dev mint bg
            //  EMITS 1 PharmacyStockUpdate event if there is stock to sell 
            //  EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
            //  EMITS 1-2 TokenAttributeUpdate events
            //  EMITS 1 ScalarTransfer event
            //  EMITS 1 InventoryUpdate event
            self._mint_bg(to, pill_id, bg);
        }
    }

    #[generate_trait]
    impl MintPillInternalImpl of MintPillInternalTrait {
        // @dev mints a pill and adds mbill attribute if have any
        //  EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
        //  EMITS 1 TokenAttributeUpdate event if mbill is not zero
        // @return the token id of the minted pill if have any
        #[inline(always)]
        fn _mint_pill(ref self: ContractState, to: ContractAddress, mbill: u256) -> u256 {
            // get the pill id to mint which is the total supply plus 1 
            let pill_id = self.erc721_enum.total_supply() + 1;
            // @dev this function already checks if tokenid is valid and  deos not exist
            // EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
            // if to address is valid
            self.erc3525._mint(to, pill_id, pill_constants::PILL_SLOT, 0);
            // add attributes to pill
            // set attr_id and value to zero as we dont want to add any other attribute other than mbill
            self._unsafe_add_attributes_to_token(pill_id, 0, 0, mbill);
            pill_id
        }

        // @dev assumes pill_id is valid 
        #[inline(always)]
        fn _mint_ing(ref self: ContractState, to: ContractAddress, pill_id: u256, index: felt252) {
            if index.is_zero() {
                return;
            }
            let attr_id = pill_constants::ING_ID;
            let slot_id = pill_constants::ING_SLOT;
            // this function checks if attr_id is redeemable and clear stock if have any
            self._mint_and_equip_token(to, slot_id, attr_id, index, pill_id);
        }

        // @dev assumes pill_id is valid 
        #[inline(always)]
        fn _mint_bg(ref self: ContractState, to: ContractAddress, pill_id: u256, index: felt252) {
            if index.is_zero() {
                return;
            }
            let attr_id = pill_constants::BG_ID;
            let slot_id = pill_constants::BG_SLOT;
            // this function checks if attr_id is redeemable and clear stock if have any
            self._mint_and_equip_token(to, slot_id, attr_id, index, pill_id);
        }
    }

    #[generate_trait]
    impl MintPillPrivateImpl of MintPillPrivateTrait {
        // @dev mints a token and automatically scalar transfer it to the pill
        //  also trys and equip the token to the pill
        #[inline(always)]
        fn _mint_and_equip_token(
            ref self: ContractState,
            receiver: ContractAddress,
            slot_id: u256,
            attr_id: u64,
            index: felt252,
            pill_id: u256
        ) {
            // assert if attrid is purchasable and not only redeemable
            self.pharmacy._assert_not_redemption_only(attr_id, index);
            // ------------------------------- clear stock ------------------------------ //
            // @dev reduce the stock if has any
            //  this function checks if there is stock to sell
            //  EMITS 1 PharmacyStockUpdate event if there is stock to sell
            self.pharmacy._clear_pharmacy_stock(attr_id, index);
            // ------------------------------- mint token ------------------------------- //
            // get highest token for trait mint
            let token_id = self.erc721_enum.total_supply() + 1;
            // @dev get contract as we are going to mint straight to the contract to save gas
            //  and avoid double transfer
            //  EMITS 3 events on mint: 1 Transfer, 1 SlotChanged, and 1 TransferValue
            let spill_contract = get_contract_address();
            self.erc3525._mint(spill_contract, token_id, slot_id, 0);
            // ----------------------------- add attributes ----------------------------- //
            // @dev add attributes to token
            //  get ing premium not total cost as only premium is added as medical bill
            //  EMITS 1-2 TokenAttributeUpdate events
            let mbill: u256 = self.pharmacy._get_eth_premium(attr_id, index);
            self._unsafe_add_attributes_to_token(token_id, attr_id, index, mbill);
            // --------------------------- transfer and equip --------------------------- //
            // @dev this set of functions acts as a scalar_transfer_from function from ERC2114 INV
            //  but with most of the assertions abstracted away
            //  use internal scalar transfer to transfer token to pill
            //  EMITS 1 ScalarTransfer event
            self.erc2114._scalar_transfer(receiver, token_id, pill_id);
            // @dev try and equip token with private function
            //  assumes that pill is already token parent and that its inventory has space
            //  assumes token is already not equipped
            //  EMITS 1 InventoryUpdate event
            self.erc2114_inv._update_token_inventory(pill_id, token_id);
        }

        // @dev use this over erc2114 internal _add_attributes_to_token function to save gas
        //  as its only a mint we dont have to check if the attr_id exist in token
        //  ASSUMES the tokenid is new 
        //  DOES NOT check if token ID exists
        //  DOES NOT check if attr_id is already in token 
        //  DOES check if attr_id value is valid and if attr_id is valid
        #[inline(always)]
        fn _unsafe_add_attributes_to_token(
            ref self: ContractState, token_id: u256, attr_id: u64, value: felt252, mbill: u256
        ) {
            let mut attr_ids = ArrayTrait::<u64>::new();
            // if attr_id is not zero add it to attr_ids array for attachment
            // and update the value using erc2114 private function
            // @dev EMITS 1 TokenAttributeUpdate event
            if attr_id.is_non_zero() && value.is_non_zero() {
                attr_ids.append(attr_id);
                // this function checks validity of attr_id and value
                self.erc2114._update_token_attr_value(token_id, attr_id, value);
            }

            // if mbill is not zero add medical bill attribute to attr_ids array for attachment
            // and update the value using erc2114 private function
            // @dev EMITS 1 TokenAttributeUpdate event
            if mbill.is_non_zero() {
                let mbill_id = pill_constants::MBILL_ID;
                let mbill_felt: felt252 = mbill.try_into().unwrap();
                attr_ids.append(mbill_id);
                self.erc2114._update_token_attr_value(token_id, mbill_id, mbill_felt);
            }
            // attach the attributes to token
            // if attr_id is empty the function will just return and do nothing
            self.erc2114._attach_attr_ids_to_token(token_id, attr_ids.span());
        }
    }
}
