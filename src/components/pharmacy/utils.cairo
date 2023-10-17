#[derive(Copy, Drop, Serde, PartialEq, starknet::Store)]
struct PharmacyStock {
    numerator: u128,
    denominator: u128,
}

#[generate_trait]
impl PharmacyStockImpl of PharmacyStockTrait {
    #[inline(always)]
    fn has_stock(self: PharmacyStock) -> bool {
        let denom = self.denominator;
        // if denom is zero means infinite supply
        // else check if numerator is less than denominator
        match denom.is_zero() {
            bool::False => { self.numerator < denom },
            bool::True => true,
        }
    }

    #[inline(always)]
    fn add_stock(ref self: PharmacyStock, ammount: u128) {
        self.denominator += ammount;
    }

    #[inline(always)]
    fn sell_stock(ref self: PharmacyStock) -> bool {
        match self.is_zero() {
            bool::False => {
                assert(self.numerator < self.denominator, 'SPill: no stock');
                self.numerator += 1;
                true
            },
            bool::True => { false },
        }
    }

    #[inline(always)]
    fn reset_stock(ref self: PharmacyStock) {
        assert(self.denominator > 0, 'SPill: stock already set');
        self.numerator = 0;
        self.denominator = 0;
    }
}

impl PharmacyStockZeroable of Zeroable<PharmacyStock> {
    #[inline(always)]
    fn zero() -> PharmacyStock {
        PharmacyStock { numerator: 0, denominator: 0 }
    }

    #[inline(always)]
    fn is_zero(self: PharmacyStock) -> bool {
        self == PharmacyStock { numerator: 0, denominator: 0 }
    }

    #[inline(always)]
    fn is_non_zero(self: PharmacyStock) -> bool {
        self != PharmacyStock { numerator: 0, denominator: 0 }
    }
}
