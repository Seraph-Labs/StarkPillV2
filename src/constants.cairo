// interface ids
const IACCESSCONTROL_ID: felt252 =
    0x23700be02858dbe2ac4dc9c9f66d0b6b0ed81ec7f970ca6844500a56ff61751;

// ---------------------------------- Roles --------------------------------- //
// @dev for access control all role, admins is default 0
//  so we must set this default role to address before actual admin role
//  role zero is essenstially the master admin role
const DEFAULT_ADMIN_ROLE: felt252 = 0;
const ADMIN_ROLE: felt252 = 'ADMIN_ROLE';

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
const PILL_NAME: felt252 = '"StarkPill"';
const ING_NAME: felt252 = '"PillIngredient"';
const BG_NAME: felt252 = '"PillBackground"';
