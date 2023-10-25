// interface ids
const IACCESSCONTROL_ID: felt252 =
    0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

// ---------------------------------- Roles --------------------------------- //
// @dev for access control all role, admins is default 0
//  so we must set this default role to address before actual admin role
//  role zero is essenstially the master admin role
const DEFAULT_ADMIN_ROLE: felt252 = 0;
const ADMIN_ROLE: felt252 = 'ADMIN_ROLE';

// ---------------------------------- Price --------------------------------- //

const PILL_BASE_PRICE: u256 = 1000000000000000_u256; // 0.001 eth

// ---------------------------------- Slots --------------------------------- //
const PILL_SLOT: u256 = 1_u256;
const ING_SLOT: u256 = 2_u256;
const BG_SLOT: u256 = 3_u256;

// ------------------------------ Attribute Ids ----------------------------- //
// string type
const NAME_ID: u64 = 1_u64; // "name", list_id = 1
const ING_ID: u64 = 2_u64; // "Ingredient", list_id = 2
const BG_ID: u64 = 3_u64; // "Background" , list_id = 3 

// number type
const MBILL_ID: u64 = 4_u64; // "Medical Bill"  
const FAME_ID: u64 = 5_u64; // "Fame"  
const DEFAME_ID: u64 = 6_u64; // "DeFame"  

// ---------------------------- Attribute Values ---------------------------- //
// @dev values for attr_id 1 in list id 1
const NO_ATTR: felt252 = 'Null';
const NO_BG_ATTR: felt252 = 'White';
const PILL_NAME: felt252 = 'StarkPill';
const ING_NAME: felt252 = 'PillIngredient';
const BG_NAME: felt252 = 'PillBackground';

// ----------------------------- Attribute Names ---------------------------- //
// string type
const NAME_ID_NAME: felt252 = 'name';
const ING_ID_NAME: felt252 = 'Ingredient';
const BG_ID_NAME: felt252 = 'Background';

// number type
const MBILL_ID_NAME: felt252 = 'Medical Bill';
const FAME_ID_NAME: felt252 = 'Fame';
const DEFAME_ID_NAME: felt252 = 'Defame';
// -------------------------------------------------------------------------- //
//                                  MetaData                                  //
// -------------------------------------------------------------------------- //
// start
const JSON_START: felt252 = 'data:application/json,';
const START_NAME: felt252 = '{"name":"';
// @dev insert name attr_id name
const SPACE_HASHTAG: felt252 = ' #';
// @dev insert token id as string

// ------------------------------- description ------------------------------ //
const PILL_DESC_1: felt252 = '","description":"an ERC2114 ';
const PILL_DESC_2: felt252 = 'cairo-2 test run ';
const PILL_DESC_3: felt252 = 'token for starkpill",';

const TRAIT_DESC_1: felt252 = '","description":"an ';
const TRAIT_DESC_2: felt252 = 'equippable ERC2114 ';
const TRAIT_DESC_3: felt252 = 'token for TestPillV2",';

// -------------------------------- image url ------------------------------- //
const IMAGE_START: felt252 = '"image":"https://arweave.net/';
// @dev insert base uri
// use one of theese files headers
const SPILL_FILE: felt252 = '/StarkPill/pill_';
const ING_FILE: felt252 = '/PillIngredient/ing_';
const BG_FILE: felt252 = '/PillBackground/bg_';
// @dev insert the tokens barcode
const IMAGE_END: felt252 = '.png",';

// ----------------------------- attributes json ---------------------------- //
const ATTR_START: felt252 = '"attributes":[';
const FIRST_TRAIT: felt252 = '{"trait_type":"';
// @dev insert attr_id name
const STR_VALUE: felt252 = '","value":"';
const NUM_VALUE: felt252 = '","value":';
// @dev insert attr_id value
const STR_VALUE_END: felt252 = '"}';
const NUM_VALUE_END: felt252 = '}';
//  if there is another trait insert this
const NEXT_TRAIT: felt252 = ',{"trait_type":"';
// @dev insert attr_id name, TRAIT_VALUE and attr_id value
const JSON_END: felt252 = ']}';
// --------------------------------- others --------------------------------- //

const NAME: felt252 = 'GetTestPilledV2';
const SYMBOL: felt252 = 'TPILLV2';
// const NAME: felt252 = 'GetStarkPilled';
// const SYMBOL: felt252 = 'SPILL';
const VOTE_COOLDOWN: u64 = 86400;
