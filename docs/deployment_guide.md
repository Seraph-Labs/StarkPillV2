# StarkPill Deployment Guide

## Step 1: Deploy Trait Catalog Contract

### Constructor requirements

1. admin address

### Required Steps

1. generate 3 trait list
    - 1: name trait list (this already generated on deployment)
    - 2: generate ingredient trait list
    - 3: generate background trait list

## Step 2: Deploy System Registry Contract

### Constructor requirements

1. admin address

### Required Steps

1. declare starkpill Mint System class hash
2. declare starkpill vbooth System class hash
3. register mint system classhash -> system_id: 1
4. register vboth system classhash -> system_id: 2

## Step 3: Deploy StarkPill Contract

### Constructor requirements

1. admin address
2. wallet address
3. eth address
4. trait catalog address

### Required Steps

1. install systems

    - install mint system: system_id 1, version 1, constructor (none)
    - install vbooth system: system_id 2, version 1, constructor (none)

2. set base uri

### What Constructor Do

1. grant default_admin_role to admin address
2. grant admin_role to admin address
3. set base pill base price to pharmacy
4. set name and symbol
5. attach trait_catalog
6. create 6 attributes
    - attr_id 1: name
    - attr_id 2: ingredient
    - attr_id 3: background
    - attr_id 4: medical bill
    - attr_id 5: fame
    - attr_id 6: defame
7. set attr_id 1 to slot attributes for slots 1,2, and 3
    - slot 1: index 1
    - slot 2: index 2
    - slot 3: index 3
8. set inventory slot criteria for slot 1: pill slot
    - slot 2: space 1
    - slot 3: space 1
9. add inventory attributes to slot 1: pill slot
    - attr_id 2
    - attr_id 3
    - attr_id 4
