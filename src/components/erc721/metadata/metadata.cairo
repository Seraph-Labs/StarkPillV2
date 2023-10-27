// erc721 metadata component tailored for starkpill
#[starknet::component]
mod ERC721MetadataComponent {
    use seraphlabs::ascii::interger::IntergerToAsciiTrait;
    use seraphlabs::data_structures::arrays::SeraphArrayTrait;
    use seraphlabs::tokens::erc2114::interface::{
        ITraitCatalogDispatcher, ITraitCatalogDispatcherTrait
    };
    use seraphlabs::tokens::erc2114::utils::{AttrType, AttrTypeTrait};
    use seraphlabs::tokens::erc2114::utils::{AttrBase, AttrBaseTrait};
    use seraphlabs::tokens::constants;
    use starkpill::components::erc721::metadata::utils;
    use starkpill::constants as pill_constants;
    use seraphlabs::tokens::src5::SRC5Component;
    use seraphlabs::tokens::erc721::{ERC721Component, interface};
    use seraphlabs::tokens::erc721::extensions::ERC721EnumComponent;
    use seraphlabs::tokens::erc3525::ERC3525Component;
    use seraphlabs::tokens::erc2114::ERC2114Component;
    use seraphlabs::tokens::erc2114::extensions::{ERC2114InvComponent, ERC2114SlotAttrComponent};
    use SRC5Component::SRC5InternalImpl;
    use ERC721Component::ERC721InternalImpl;
    use ERC3525Component::IERC3525Impl;
    use ERC2114Component::{IERC2114Impl, ERC2114PrivateImpl};
    use ERC2114InvComponent::{IERC2114InvImpl, ERC2114InvPrivateImpl};
    use ERC2114SlotAttrComponent::IERC2114SlotAttrImpl;

    #[storage]
    struct Storage {
        erc721_name: felt252,
        erc721_symbol: felt252,
        erc721_base_uri: LegacyMap::<felt252, felt252>,
        erc721_base_uri_len: felt252,
    }

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event {}

    // -------------------------------------------------------------------------- //
    //                               For Embeddable                               //
    // -------------------------------------------------------------------------- //

    #[embeddable_as(ERC721MetadataImpl)]
    impl ERC721Metadata<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +ERC721EnumComponent::HasComponent<TContractState>,
        +ERC3525Component::HasComponent<TContractState>,
        +ERC2114Component::HasComponent<TContractState>,
        +ERC2114InvComponent::HasComponent<TContractState>,
        +ERC2114SlotAttrComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of interface::IERC721Metadata<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            IERC721MetadataImpl::name(self)
        }

        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            IERC721MetadataImpl::symbol(self)
        }

        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> Array<felt252> {
            IERC721MetadataImpl::token_uri(self, token_id)
        }
    }

    // -------------------------------------------------------------------------- //
    //                                 Initializer                                //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl ERC721MetadataInitializerImpl<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC721MetadataInitializerTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>, name: felt252, symbol: felt252) {
            self.erc721_name.write(name);
            self.erc721_symbol.write(symbol);
            let mut src5 = self.get_src5_mut();
            src5.register_interface(constants::IERC721_METADATA_ID);
        }
    }

    // -------------------------------------------------------------------------- //
    //                             External Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl IERC721MetadataImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +ERC721EnumComponent::HasComponent<TContractState>,
        +ERC3525Component::HasComponent<TContractState>,
        +ERC2114Component::HasComponent<TContractState>,
        +ERC2114InvComponent::HasComponent<TContractState>,
        +ERC2114SlotAttrComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC721MetadataImplTrait<TContractState> {
        #[inline(always)]
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            self.erc721_name.read()
        }

        #[inline(always)]
        fn symbol(self: @ComponentState<TContractState>) -> felt252 {
            self.erc721_symbol.read()
        }

        #[inline(always)]
        fn token_uri(self: @ComponentState<TContractState>, token_id: u256) -> Array<felt252> {
            let erc3525 = self.get_erc3525();
            // get token slot
            let slot_id = erc3525.slot_of(token_id);
            if slot_id == pill_constants::PILL_SLOT {
                let uri = self._get_pill_uri(token_id);
                return uri;
            } else if slot_id == pill_constants::ING_SLOT {
                let uri = self._get_ing_uri(token_id);
                return uri;
            } else if slot_id == pill_constants::BG_SLOT {
                let uri = self._get_bg_uri(token_id);
                return uri;
            }
            ArrayTrait::<felt252>::new()
        }
    }

    // -------------------------------------------------------------------------- //
    //                             Internal Functions                             //
    // -------------------------------------------------------------------------- //

    #[generate_trait]
    impl ERC721MetadataInternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +ERC721EnumComponent::HasComponent<TContractState>,
        +ERC3525Component::HasComponent<TContractState>,
        +ERC2114Component::HasComponent<TContractState>,
        +ERC2114InvComponent::HasComponent<TContractState>,
        +ERC2114SlotAttrComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of ERC721MetadataInternalTrait<TContractState> {
        #[inline(always)]
        fn _get_pill_uri(self: @ComponentState<TContractState>, token_id: u256) -> Array<felt252> {
            let erc2114 = self.get_erc2114();
            let erc2114_inv = self.get_erc2114_inv();
            let erc2114_slot_attr = self.get_erc2114_slot_attr();
            // constants
            let slot_id = pill_constants::PILL_SLOT;
            let name_id = pill_constants::NAME_ID;
            let ing_id = pill_constants::ING_ID;
            let bg_id = pill_constants::BG_ID;
            let mbill_id = pill_constants::MBILL_ID;
            let fame_id = pill_constants::FAME_ID;
            let defame_id = pill_constants::DEFAME_ID;
            // get uri values
            // read straight from storage to get base
            let ing_base: AttrBase = erc2114.ERC2114_attr_base.read(ing_id);
            let bg_base: AttrBase = erc2114.ERC2114_attr_base.read(bg_id);

            let name = erc2114_slot_attr.slot_attribute_value(slot_id, name_id);
            let base_uri = self._get_base_uri();
            // use private function to get index to avoid double calling for value
            let ing = erc2114_inv._find_equipped_attr_string_value(token_id, ing_id);
            let bg = erc2114_inv._find_equipped_attr_string_value(token_id, bg_id);
            let ing_value = erc2114
                ._get_trait_catalog()
                .trait_list_value_by_index(ing_base.val_type.get_list_id(), ing);

            let bg_value = erc2114
                ._get_trait_catalog()
                .trait_list_value_by_index(bg_base.val_type.get_list_id(), bg);
            let mbill_name = erc2114.attribute_name(mbill_id);
            let mbill_value: u256 = erc2114_inv.equipped_attribute_value(token_id, mbill_id).into();
            let fame_name = erc2114.attribute_name(fame_id);
            let fame_value: u256 = erc2114.attribute_value(token_id, fame_id).into();
            let defame_name = erc2114.attribute_name(defame_id);
            let defame_value: u256 = erc2114.attribute_value(token_id, defame_id).into();
            utils::generate_pill_uri(
                name,
                token_id,
                base_uri,
                ing,
                bg,
                ing_base.name,
                ing_value,
                bg_base.name,
                bg_value,
                mbill_name,
                mbill_value,
                fame_name,
                fame_value,
                defame_name,
                defame_value
            )
        }

        #[inline(always)]
        fn _get_ing_uri(self: @ComponentState<TContractState>, token_id: u256) -> Array<felt252> {
            let erc2114 = self.get_erc2114();
            let erc2114_slot_attr = self.get_erc2114_slot_attr();
            // constants
            let slot_id = pill_constants::ING_SLOT;
            let name_id = pill_constants::NAME_ID;
            let trait_attr_id = pill_constants::ING_ID;
            let mbill_id = pill_constants::MBILL_ID;

            let name = erc2114_slot_attr.slot_attribute_value(slot_id, name_id);
            let base_uri = self._get_base_uri();
            let index = erc2114.ERC2114_token_attr_value.read((token_id, trait_attr_id));
            let trait_name = erc2114.attribute_name(trait_attr_id);
            let trait_value = erc2114.attribute_value(token_id, trait_attr_id);
            let mbill_name = erc2114.attribute_name(mbill_id);
            let mbill_value: u256 = erc2114.attribute_value(token_id, mbill_id).into();
            utils::generate_trait_uri(
                true,
                name,
                token_id,
                base_uri,
                index,
                trait_name,
                trait_value,
                mbill_name,
                mbill_value
            )
        }

        #[inline(always)]
        fn _get_bg_uri(self: @ComponentState<TContractState>, token_id: u256) -> Array<felt252> {
            let erc2114 = self.get_erc2114();
            let erc2114_slot_attr = self.get_erc2114_slot_attr();
            // constants
            let slot_id = pill_constants::BG_SLOT;
            let name_id = pill_constants::NAME_ID;
            let trait_attr_id = pill_constants::BG_ID;
            let mbill_id = pill_constants::MBILL_ID;

            let name = erc2114_slot_attr.slot_attribute_value(slot_id, name_id);
            let base_uri = self._get_base_uri();
            let index = erc2114.ERC2114_token_attr_value.read((token_id, trait_attr_id));
            let trait_name = erc2114.attribute_name(trait_attr_id);
            let trait_value = erc2114.attribute_value(token_id, trait_attr_id);
            let mbill_name = erc2114.attribute_name(mbill_id);
            let mbill_value: u256 = erc2114.attribute_value(token_id, mbill_id).into();
            utils::generate_trait_uri(
                false,
                name,
                token_id,
                base_uri,
                index,
                trait_name,
                trait_value,
                mbill_name,
                mbill_value
            )
        }
        fn _get_base_uri(self: @ComponentState<TContractState>) -> Array<felt252> {
            let len = self.erc721_base_uri_len.read();
            let mut base_uri = ArrayTrait::<felt252>::new();
            let mut index = 0;
            loop {
                if index == len {
                    break ();
                }
                base_uri.append(self.erc721_base_uri.read(index));
                index += 1;
            };
            base_uri
        }

        fn _set_base_uri(ref self: ComponentState<TContractState>, mut base_uri: Array<felt252>) {
            let len = base_uri.len();
            let mut index = 0;
            loop {
                match base_uri.pop_front() {
                    Option::Some(value) => {
                        self.erc721_base_uri.write(index, value);
                        index += 1;
                    },
                    Option::None(()) => { break (); },
                };
            };
            // write length to storage
            self.erc721_base_uri_len.write(len.into());
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

    #[generate_trait]
    impl GetERC721<
        TContractState,
        +HasComponent<TContractState>,
        +ERC721Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC721Trait<TContractState> {
        #[inline(always)]
        fn get_erc721(
            self: @ComponentState<TContractState>
        ) -> @ERC721Component::ComponentState<TContractState> {
            let contract = self.get_contract();
            ERC721Component::HasComponent::<TContractState>::get_component(contract)
        }

        #[inline(always)]
        fn get_erc721_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC721Component::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC721Component::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }

    #[generate_trait]
    impl GetER3525<
        TContractState,
        +HasComponent<TContractState>,
        +ERC3525Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC3525Trait<TContractState> {
        #[inline(always)]
        fn get_erc3525(
            self: @ComponentState<TContractState>
        ) -> @ERC3525Component::ComponentState<TContractState> {
            let contract = self.get_contract();
            ERC3525Component::HasComponent::<TContractState>::get_component(contract)
        }
        #[inline(always)]
        fn get_erc3525_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC3525Component::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC3525Component::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }

    #[generate_trait]
    impl GetERC2114<
        TContractState,
        +HasComponent<TContractState>,
        +ERC2114Component::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC2114Trait<TContractState> {
        #[inline(always)]
        fn get_erc2114(
            self: @ComponentState<TContractState>
        ) -> @ERC2114Component::ComponentState<TContractState> {
            let contract = self.get_contract();
            ERC2114Component::HasComponent::<TContractState>::get_component(contract)
        }
        #[inline(always)]
        fn get_erc2114_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC2114Component::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC2114Component::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }

    #[generate_trait]
    impl GetERC2114SlotAttr<
        TContractState,
        +HasComponent<TContractState>,
        +ERC2114SlotAttrComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC2114SlotAttrTrait<TContractState> {
        #[inline(always)]
        fn get_erc2114_slot_attr(
            self: @ComponentState<TContractState>
        ) -> @ERC2114SlotAttrComponent::ComponentState<TContractState> {
            let contract = self.get_contract();
            ERC2114SlotAttrComponent::HasComponent::<TContractState>::get_component(contract)
        }
        #[inline(always)]
        fn get_erc2114_slot_attr_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC2114SlotAttrComponent::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC2114SlotAttrComponent::HasComponent::<
                TContractState
            >::get_component_mut(ref contract)
        }
    }

    #[generate_trait]
    impl GetERC2114Inv<
        TContractState,
        +HasComponent<TContractState>,
        +ERC2114InvComponent::HasComponent<TContractState>,
        +Drop<TContractState>
    > of GetERC2114InvTrait<TContractState> {
        #[inline(always)]
        fn get_erc2114_inv(
            self: @ComponentState<TContractState>
        ) -> @ERC2114InvComponent::ComponentState<TContractState> {
            let contract = self.get_contract();
            ERC2114InvComponent::HasComponent::<TContractState>::get_component(contract)
        }
        #[inline(always)]
        fn get_erc2114_inv_mut(
            ref self: ComponentState<TContractState>
        ) -> ERC2114InvComponent::ComponentState<TContractState> {
            let mut contract = self.get_contract_mut();
            ERC2114InvComponent::HasComponent::<TContractState>::get_component_mut(ref contract)
        }
    }
}
