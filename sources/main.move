module food_chain::food_chain_system {

    // Imports
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Clock, timestamp_ms};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{TxContext, sender};
    use sui::table::{Self, Table};

    use std::option::{Option, none, some, borrow};
    use std::string::{String};
    use std::vector::{Self};

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
    struct Product has key, store {
        id: UID,
        inner: ID,
        supplier: address,
        consumers: Table<address, Consumer>,
        description: String,
        quality: u64,
        price: u64,
        dispute: bool,
        status: bool,
        consumer: Option<address>,
        order_submitted: bool,
        created_at: u64,
        deadline: u64,
        payment: Balance<SUI>, // Added payment field
    }
    
    struct ProductCap has key {
        id: UID,
        product_id: ID
    }
    
    // Consumer Struct
    struct Consumer has key, store {
        id: UID,
        product_id: ID,
        supplier: address,
        description: String,
        requirements: vector<String>
    }
    
    // Complaint Struct
    struct Complaint has key, store {
        id: UID,
        consumer: address,
        supplier: address,
        reason: String,
        decision: bool,
    }
    
    struct AdminCap has key {id: UID}

    fun init(ctx: &mut TxContext) {
        transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
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
            quality: quality_,
            price: price_,
            dispute: false,
            status: false,
            consumer: none(),
            order_submitted: false,
            created_at: timestamp_ms(c),
            deadline: deadline_,
            payment: balance::zero(), // Initialize payment balance
        });

        transfer::transfer(ProductCap{id: object::new(ctx), product_id: inner_}, sender(ctx));
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
        assert!(coin::value(&coin) >= product.price, ERROR_INSUFFICIENT_FUNDS);

        let consumer = table::remove(&mut product.consumers, chosen);
        let payment = coin::into_balance(coin);
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

        let payment: Balance<SUI> = balance::withdraw_all(&mut product.payment); // Add type annotation
        let coin: Coin<SUI> = coin::from_balance(payment, ctx); // Add type annotation

        transfer::public_transfer(coin, *borrow(&product.consumer));
    }

    // Additional functions for handling complaints and dispute resolutions
    public fun file_complaint(product: &mut Product, c:&Clock, reason: String, ctx: &mut TxContext) {
        assert!(timestamp_ms(c) > product.deadline, ERROR_TIME_IS_UP); // Ensure that the complaint is filed after the product deadline
        
        let complainer = sender(ctx);
        let supplier = product.supplier;
        
        // Ensure that the complaint is filed by either the consumer or the supplier
         assert!(complainer == sender(ctx) || supplier == sender(ctx), ERROR_INCORRECT_SUPPLIER);

        // Create the complaint
        let complaint = Complaint{
            id: object::new(ctx),
            consumer: complainer,
            supplier: supplier,
            reason: reason,
            decision: false,
        };

        // Mark the product as disputed
        product.dispute = true;

        transfer::share_object(complaint);
    }

    // Admin or arbitrator decides the outcome of a dispute
    public fun resolve_dispute(_: &AdminCap, product: &mut Product, complaint: &mut Complaint, decision: bool, ctx: &mut TxContext) {
        assert!(product.dispute, ERROR_DISPUTE_FALSE); // Ensure there is an active dispute
        
        // Decision process
        if (decision) {
            // If decision is true, transfer the payment to the consumer
            let payment: Balance<SUI> = balance::withdraw_all(&mut product.payment); // Add type annotation
            let coin: Coin<SUI> = coin::from_balance(payment, ctx); // Add type annotation
            transfer::public_transfer(coin, complaint.consumer);
        } else {
            // If decision is false, return the payment to the supplier
            let payment: Balance<SUI> = balance::withdraw_all(&mut product.payment); // Add type annotation
            let coin: Coin<SUI> = coin::from_balance(payment, ctx); // Add type annotation
            transfer::public_transfer(coin, product.supplier);
            
            // Close the dispute
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
