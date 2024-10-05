module hello_market::FirstContract {
    use std::signer;// for authenticity purpose
    use std::string::String;// for writing strings
    use aptos_framework::guid; // globally unique identifier
    use aptos_framework::coin; // helps in managing the transaction and excahnge of currencies
    use aptos_framework::account; // use to manage the accounts
    use aptos_framework::timestamp; // use to manage the transaction timestamps 
    use aptos_std::event::{Self , EventHandling}; // for event handling and permissions
    use aptos_std::table::{Self , Table};// It is  basically a data structures which store key value pair & updating the data
    use aptos_token::token; // token management
    use aptos_token::token_coin_swap::{
        list_token_for_swap, excahnge_coin_for_token
    };


    const SELLER_CAN_NOT_BE_BUYER: u64 = 1;
    const FEE_DENOMINATIOR: u64 =10000;
    // different structs are used here:
    // ContractId, Contract, ContractEvents, OfferStore, Offer,CreateContractEvents, ListTokenEvent, BuyTokenEvent
    
    struct ContractId has store, copy,drop {
        contract_name:String,
        contract_address: address,

    }
    struct Contract has key {
        contract_id:ContractId,
        fee_numerator: u64,
        fee_payee: address,
        signer_cap: account::SignerCapability
    }
    struct OfferStore has key{
        offers: Table<token::TokenId, offer> //data structure: key value pair
    }

    struct Offer has drop, store{
      contract_id:ContractId,
      seller: address,
      price: u64,
    }

struct CreateContractEvents has store , drop {
    contract_id: ContractId,
    fee_numerator: u64,
    fee_payee: address
}
struct ListTokenEvent has store , drop {
    contract_id: ContractId,
    token_id: token::TokenId,
    seller:address,
    price:u64,
    timestamp: u64,
    offer_id: u64
}

struct BuyTokenEvent has store , drop {
    contract_id: ContractId,
    token_id: token::TokenId,
    seller: address,
    buyer: address,
    price: u64,
    timestamps: u64,
    offer_id: u64
}

//Functions
// get_resources_account_cap ,get_royalty_free_rate, create_contract 
// list_token , buy_token

fun get_resources_account_cap (contract_address: address): signer acquires Contract {
    let market = borrow_global<Contract>(contract_address);
    account::create_signer_with_capability(&market.signer_cap);
}
fun get_royalty_fee_rate (token_id: token::TokenId): u64 {
    let royalty =  token::get_royalty(token_id);
    let royalty_denominator = token::get_royalty_denominator(&royalty);

    let royalty_fee_rate = if(royalty_denominator==0){
        0
    }
    else {
        token::get_royalty_numerator(&royalty) / token::get_royalty_denominator(&)
    }
    royalty_fee_rate
}

public entry fun create_contract<CoinType>(sender: &signer,
                                            contract_name = string,
                                            fee_numerator: u64,
                                            fee_payee: address,
                                            initial_fund: u64) acquires ContractEvents {

    let sender_addr = signer::address_of(sender);
    let contract_id = ContractId{contract_name, contract_address::sender_addr};

    if(!exists<ContractEvents>(sender_addr)){
        move_to(sender,ContractEvents {
            create_contract_event: account::new_event_handle<CreateContractEvents>(sender),
            list_token_event: account::new_event_habdle<ListTokenEvent>(sender),
            buy_token_event: account::new_event_handle<BuyTokenEvent>(sender)
        });
    }  ;
    if(!exists<OfferStore>(sender_addr)){
        move_to(sender, OfferStore {
            offers:table ::new()
        });
    };

    if(!exists<Contract>(sender_addr)){
        let(resource_signer, signer_cap)= account::create_resource_account(sender,x"0:)token::initialize_token_store(&resource_signer);
        move_to(sender,Contract{
           contract_id, fee_numerator, fee_payee , signerr_cap
        });
        let contract_events = borrow_global_mut<ContractEvents>(sender_addr);
        event::emit_event(&mut market_events.create_market_event , CreateContractEvents{
            contract_id , fee_numerator, fee_payee
        });
    };
    
    let resource_signer = get_resource_account_cap(sender_addr);
    if(!coin:: is_account_registered<CoinType>(signer::address_of(&resource_signer ))){
        coin:: register<CoinType>(&resource_signer);
    };

    if(initial_fund >0){
        coin::transfer<CoinType>(sender, signer::address_of(&resource_signer), initial_fund);
    }
     }

     public entry fun list_token<CoinType> (
        sender: &signer,
        contract_address: address,
        contract_name: string,
        creator:address,
        collection: String,
        name: String,
        propery_version: u64,
        price: u64
     ) acquires ContractEvents, Contract , OfferStore {
        let contract_id = ContractId{contract_name , contract_address};
        let resource_signer = get_resource_account_cap(contract_address);
        let seller_addr = signer::address_of(seller);
        let token_id = token::create_token_id_raw(creator, collection, name , propery_version);
        let token = token::withdraw_token(seller, token_id,1);


        token::deposit_token(&resource_signer,token);
        list_token_for_swap<CoinType>(&resource_signer , creator,collection , name , propery_version,1)

        let offer_store = borrow_global_mut<OfferStore>(contract_address);
        table::add(&mut offer_store.offers, token_id, offer{
            contract_id , seller: seller_addr , price
        });

        let guid = account::create_guid(&resource_signer);
        let contract_events = borrow_global_mut<ContractEvents>(market_address);


        event::emit_event(&mut contract_events.list_token_event, ListTokenEvent{
            contract_id,
            token_id,
            seller:seller_addr,
            price,
            timestamp,
            offer_id: guid:: cration_num(&guid)
        });

     }
    public entry fun buy_token<CoinType>(
        buyer: &signer, 
        contract_address: address,
        contract_name: String,
        creator: address,
        collection: address,
        name: String,
        propery_version: u64,
        price:u64,
        offer_id: u64

     ) acquires ContractEvents ,Contract , OfferStore {

        let contract_id =ContractId(contract_name, contract_address);
        let token_id = token::create_token_id_raw(creator , collection, name, propery_version);
        let offer_store = borrow_global_mut<OfferStore>(contract_address);
        let seller =  table:: borrow(&offer_store.offers, token_id).seller;
        let buyer_addr = signer:: address_of(buyer);

        assert!(seller != buyer_addr ,SELLER_CAN_NOT_BE_BUYER );


        let resource_signer = get_resource_account_cap(market_address);
        excahnge_coin_for_token<CoinType>(buyer , price ,signer::address_of(&resource_signer),
                                                    creator, collection , name , propery_version, 1);

                                                    let royalty_fee = price* get_royalty_fee_rate(token_id);
                                                    let contract = borrow_global<Contract>(contract_address);
                                                    let contract_fee = price* contract_fee_numerator/FEE_DENOMINATIOR;
                                                    let amount = price - market_fee - royalty_fee;
 
    coin:: transfer<CoinType>(&resource_signer , seller, amount);
    table::remove(&mut offer_store.offers , token_id);
    let contract_events = borrow_global_mut<ContractEvents>(contract_address);

    event::emit_event(&mut contract_events.buy_token_event, BuyTokenEvent{
        contract_id,
        token_id,
        seller,
        buyer:buyer_addr,
        price,
        timestamp: timestamp::now_microseconds(),
        offer_id
    })
     }



}