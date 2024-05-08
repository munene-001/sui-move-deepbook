module food_chain::food_chain_system {

    // Imports
    use sui::transfer;
    use sui::coin::{Coin, value};
    use sui::clock::{Clock, timestamp_ms};
    use sui::object::{self, UID, ID};
    use sui::balance::{Balance, withdraw_all, zero};
    use sui::tx_context::{TxContext, sender};
    use sui::table::{self, Table};
    use std::option::{Option, none, some};
    use std::string::String;
    use std::vector::{Vector, empty, contains, push_back};

    // Errors
    const ERROR_INVALID_QUALITY: u64 = 0;
    const ERROR_PRODUCT_OUT_OF_STOCK: u64 = 1;
    const ERROR_INVALID_CAP: u64 = 2;
    const ERROR_INSUFFICIENT_FUNDS: u64 = 3;
    const ERROR_ORDER_NOT_SUBMITTED: u64 = 4;
    const ERROR_WRONG_ADDRESS: u64 = 5;
    const ERROR_TIME_IS_UP: u64 = 6;
    const ERROR_INCORRECT_SUPPLIER: u64 = 7;
    const ERROR_DISPUTE_FALSE: u64 = 8;

    // Struct definitions
    
    // Product Struct
    struct Product {
        id: UID,
        inner: ID,
        supplier: address,
        consumers: Table<address, Consumer>,
        description: String,
        price: u64,
        dispute: bool,
        status: bool,
        consumer: Option<address>,
        order_submitted: bool,
        created_at: u64,
        deadline: u64,
        payment: Balance<SUI>,
    }
    
    struct ProductCap {
        id: UID,
        product_id: ID
    }
    
    // Consumer Struct
    struct Consumer {
        id: UID,
        product_id: ID,
        supplier: address,
        description: String,
        requirements: Vector<String>
    }
    
    // Complaint Struct
    struct Complaint {
        id: UID,
        consumer: address,
        supplier: address,
        reason: String,
        decision: bool,
    }
    
    struct AdminCap { id: UID }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, sender(ctx));
    }

    // Accessors
    public fun get_product_description(product: &Product): String {
        product.description
    }

    public fun get_product_price(product: &Product): u64 {
        product.price
    }

    public fun get_product_status(product: &Product): bool {
        product.status
    }

    public fun get_product_deadline(product: &Product): u64 {
        product.deadline
    }

    // Public - Entry functions

    // Create a new product for sale
    public entry fun new_product(
        c: &Clock, 
        description_: String,
        quality_: u64,
        price_: u64, 
        duration_: u64, 
        ctx: &mut TxContext
    ) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        let deadline_ = timestamp_ms(c) + duration_;

        transfer::share_object(Product {
            id: id_,
            inner: inner_,
            supplier: sender(ctx),
            consumers: table::new(ctx),
            description: description_,
            price: price_,
            dispute: false,
            status: false,
            consumer: none(),
            order_submitted: false,
            created_at: timestamp_ms(c),
            deadline: deadline_,
            payment: balance::zero(),
        });

        transfer::transfer(ProductCap { id: object::new(ctx), product_id: inner_ }, sender(ctx));
    }
    
    public fun new_consumer(product: ID, description_: String, ctx: &mut TxContext) : Consumer {
        let consumer = Consumer {
            id: object::new(ctx),
            product_id: product,
            supplier: sender(ctx),
            description: description_,
            requirements: vector::empty()
        };
        consumer
    }

    public fun add_requirement(consumer: &mut Consumer, requirement: String) {
        assert!(!vector::contains(&consumer.requirements, &requirement), ERROR_INVALID_QUALITY);
        vector::push_back(&mut consumer.requirements, requirement);
    }

    public fun order_product(product: &mut Product, consumer: Consumer, ctx: &mut TxContext) {
        assert!(!product.status, ERROR_PRODUCT_OUT_OF_STOCK);
        table::add(&mut product.consumers, sender(ctx), consumer);
    }

    public fun choose_consumer(cap: &ProductCap, product: &mut Product, coin: Coin<SUI>, chosen: address) : Consumer {
        assert!(cap.product_id == object::id(product), ERROR_INVALID_CAP);
        assert!(value(&coin) >= product.price, ERROR_INSUFFICIENT_FUNDS);

        let consumer = table::remove(&mut product.consumers, chosen);
        let payment = withdraw_all(&mut product.payment);
        balance::join(&mut product.payment, payment);
        product.status = true;
        product.consumer = some(chosen);

        consumer
    }

    public fun submit_order(product: &mut Product, c: &Clock, ctx: &mut TxContext) {
        assert!(timestamp_ms(c) < product.deadline, ERROR_TIME_IS_UP);
        assert!(*borrow(&product.consumer) == sender(ctx), ERROR_WRONG_ADDRESS);
        product.order_submitted = true;
    }

    public fun confirm_order(cap: &ProductCap, product: &mut Product, ctx: &mut TxContext) {
        assert!(cap.product_id == object::id(product), ERROR_INVALID_CAP);
        assert!(product.order_submitted, ERROR_ORDER_NOT_SUBMITTED);

        let payment: Balance<SUI> = withdraw_all(&mut product.payment);
        let coin: Coin<SUI> = coin::from_balance(payment, ctx);

        transfer::public_transfer(coin, *borrow(&product.consumer));
    }

    // Additional functions for handling complaints and dispute resolutions
    public fun file_complaint(product: &mut Product, c:&Clock, reason: String, ctx: &mut TxContext) {
        assert!(timestamp_ms(c) > product.deadline, ERROR_TIME_IS_UP);
        
        let complainer = sender(ctx);
        let supplier = product.supplier;
        
        assert!(complainer == sender(ctx) || supplier == sender(ctx), ERROR_INCORRECT_SUPPLIER);

        let complaint = Complaint {
            id: object::new(ctx),
            consumer: complainer,
            supplier: supplier,
            reason: reason,
            decision: false,
        };

        product.dispute = true;

        transfer::share_object(complaint);
    }

    public fun resolve_dispute(_: &AdminCap, product: &mut Product, complaint: &mut Complaint, decision: bool, ctx: &mut TxContext) {
        assert!(product.dispute, ERROR_DISPUTE_FALSE);
        
        if decision {
            let payment: Balance<SUI> = withdraw_all(&mut product.payment);
            let coin: Coin<SUI> = coin::from_balance(payment, ctx);
            transfer::public_transfer(coin, complaint.consumer);
        } else {
            let payment: Balance<SUI> = withdraw_all(&mut product.payment);
            let coin: Coin<SUI> = coin::from_balance(payment, ctx);
            transfer::public_transfer(coin, product.supplier);
            
            product.dispute = false;
            complaint.decision = decision;
        }
    }

    // Helper function to add requirements to a consumer
    public fun add_requirements(consumer: &mut Consumer, requirements: String) {
        assert!(!vector::contains(&consumer.requirements, &requirements), ERROR_INVALID_QUALITY);
        vector::push_back(&mut consumer.requirements, requirements);
    }
}
