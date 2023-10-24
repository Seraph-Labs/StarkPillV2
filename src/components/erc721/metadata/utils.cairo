use seraphlabs::ascii::interger::IntergerToAsciiTrait;
use seraphlabs::data_structures::arrays::SeraphArrayTrait;
use starkpill::constants;

fn generate_pill_uri(
    name: felt252,
    token_id: u256,
    base_uri: Array<felt252>,
    ing: felt252,
    bg: felt252,
    ing_name: felt252,
    ing_value: felt252,
    bg_name: felt252,
    bg_value: felt252,
    mbill_name: felt252,
    mbill_value: u256,
    fame_name: felt252,
    fame_value: u256,
    defame_name: felt252,
    defame_value: u256,
) -> Array<felt252> {
    let mut uri = ArrayTrait::<felt252>::new();
    uri.append(constants::JSON_START);
    uri.append(constants::START_NAME);
    uri.append(name);
    uri.append(constants::SPACE_HASHTAG);
    let token_id_ascii: Array<felt252> = token_id.to_ascii();
    uri.append_mut_array(token_id_ascii);
    uri.append(constants::PILL_DESC_1);
    uri.append(constants::PILL_DESC_2);
    uri.append(constants::PILL_DESC_3);
    uri.append(constants::IMAGE_START);
    uri.append_mut_array(base_uri);
    uri.append(constants::SPILL_FILE);
    // generate barcode for ing
    generate_trait_barcode(ref uri, ing);
    // generate barcode for bg 
    generate_trait_barcode(ref uri, bg);
    uri.append(constants::IMAGE_END);
    uri.append(constants::ATTR_START);
    // ingredient trait
    uri.append(constants::FIRST_TRAIT);
    uri.append(ing_name);
    uri.append(constants::STR_VALUE);
    uri.append(get_attr_str_value(ing_value));
    uri.append(constants::STR_VALUE_END);
    // background trait
    uri.append(constants::NEXT_TRAIT);
    uri.append(bg_name);
    uri.append(constants::STR_VALUE);
    let new_bg_val = match bg_value.is_zero() {
        bool::False => bg_value,
        bool::True => constants::NO_BG_ATTR,
    };
    uri.append(new_bg_val);
    uri.append(constants::STR_VALUE_END);
    // mbill trait
    uri.append(constants::NEXT_TRAIT);
    uri.append(mbill_name);
    uri.append(constants::NUM_VALUE);
    let mut mbill_ascii: Array<felt252> = mbill_value.to_ascii();
    uri.append_array(ref mbill_ascii);
    uri.append(constants::NUM_VALUE_END);
    // fame trait
    uri.append(constants::NEXT_TRAIT);
    uri.append(fame_name);
    uri.append(constants::NUM_VALUE);
    let mut fame_ascii: Array<felt252> = fame_value.to_ascii();
    uri.append_array(ref fame_ascii);
    uri.append(constants::NUM_VALUE_END);
    // defame trait
    uri.append(constants::NEXT_TRAIT);
    uri.append(defame_name);
    uri.append(constants::NUM_VALUE);
    let mut defame_ascii: Array<felt252> = defame_value.to_ascii();
    uri.append_array(ref defame_ascii);
    uri.append(constants::NUM_VALUE_END);
    // close json
    uri.append(constants::JSON_END);
    uri
}

fn generate_trait_uri(
    is_ing: bool,
    name: felt252,
    token_id: u256,
    base_uri: Array<felt252>,
    index: felt252,
    trait_name: felt252,
    trait_value: felt252,
    mbill_name: felt252,
    mbill_value: u256,
) -> Array<felt252> {
    let mut uri = ArrayTrait::<felt252>::new();
    uri.append(constants::JSON_START);
    uri.append(constants::START_NAME);
    uri.append(name);
    uri.append(constants::SPACE_HASHTAG);
    let token_id_ascii: Array<felt252> = token_id.to_ascii();
    uri.append_mut_array(token_id_ascii);
    uri.append(constants::TRAIT_DESC_1);
    uri.append(constants::TRAIT_DESC_2);
    uri.append(constants::TRAIT_DESC_3);
    uri.append(constants::IMAGE_START);
    uri.append_mut_array(base_uri);

    let file_name = match is_ing {
        bool::False => constants::BG_FILE,
        bool::True => constants::ING_FILE,
    };
    uri.append(file_name);
    // generate barcode for trait 
    generate_trait_barcode(ref uri, index);
    uri.append(constants::IMAGE_END);
    uri.append(constants::ATTR_START);
    // ingredient trait
    uri.append(constants::FIRST_TRAIT);
    uri.append(trait_name);
    uri.append(constants::STR_VALUE);
    uri.append(get_attr_str_value(trait_value));
    uri.append(constants::STR_VALUE_END);
    // mbill trait
    uri.append(constants::NEXT_TRAIT);
    uri.append(mbill_name);
    uri.append(constants::NUM_VALUE);
    let mut mbill_ascii: Array<felt252> = mbill_value.to_ascii();
    uri.append_array(ref mbill_ascii);
    uri.append(constants::NUM_VALUE_END);
    // close json
    uri.append(constants::JSON_END);
    uri
}

#[inline(always)]
fn generate_trait_barcode(ref barcode: Array<felt252>, index: felt252) {
    if index.is_zero() {
        barcode.append('000');
        return;
    }

    // convert index to u32
    let num: u32 = index.try_into().unwrap();
    // if index is smaller than 100 add 0 at the front
    // if index is smaller than 10 add 00 at the front 
    if num < 100 {
        match num < 10 {
            bool::False => barcode.append('0'),
            bool::True => barcode.append('00'),
        };
    }
    // convert num to ascii
    let ascii: felt252 = num.to_ascii();
    barcode.append(ascii);
}

#[inline(always)]
fn get_attr_str_value(value: felt252) -> felt252 {
    match value.is_zero() {
        bool::False => value,
        bool::True => constants::NO_ATTR,
    }
}
// -------------------------------------------------------------------------- //
//                                 Array Trait                                //
// -------------------------------------------------------------------------- //

#[generate_trait]
impl ArrayImpl<T, impl TDrop: Drop<T>, impl TCopy: Copy<T>> of SPillArrayTrait<T> {
    fn append_mut_array(ref self: Array<T>, mut values: Array<T>) {
        loop {
            match values.pop_front() {
                Option::Some(val) => self.append(val),
                Option::None(()) => { break (); },
            };
        }
    }

    fn append_mut_span(ref self: Array<T>, mut values: Span<T>) {
        loop {
            match values.pop_front() {
                Option::Some(val) => self.append(*val),
                Option::None(()) => { break (); },
            };
        }
    }
}
