module sui_bank::bank {
  // === Imports ===

  use sui::sui::SUI;
  use sui::transfer;
  use sui::coin::{Self, Coin};
  use sui::object::{Self, UID};
  use sui::balance::{Self, Balance};
  use sui::tx_context::{Self, TxContext};
  
  // === Friends ===

  friend sui_bank::lending;

  // === Errors ===

  const ENotEnoughBalance: u64 = 0;
  const EPayYourLoan: u64 = 1;
  const EAccountMustBeEmpty: u64 = 2;

  // === Constants ===

  const FEE: u128 = 5;

  // === Structs ===

  struct Bank has key {
    id: UID,
    balance: Balance<SUI>,
    admin_balance: Balance<SUI>,
  }

  struct Account has key, store {
    id: UID,
    debt: u64,
    balance: u64
  }

  struct OwnerCap has key, store {
    id: UID
  }  

  struct LiquidityPool has key {
    id: UID,
    total_supply: u64,
    reserves: Balance<SUI>,
    admin_balance: Balance<SUI>,
}


struct Vote {
    voter: address,
    weight: u64,
    choice: bool, // true for approval, false for rejection
}

  // === Init ===

  public fun init_pool(ctx: &mut TxContext) {
    transfer::share_object(
        LiquidityPool {
            id: object::new(ctx),
            total_supply:  0,
            reserves: balance::zero(),
            admin_balance: balance::zero(),
        }
    );

    transfer::transfer(OwnerCap { id: object::new(ctx) }, tx_context::sender(ctx));
  }  

  // === Public-Mutative Functions ===

  public fun new_account(ctx: &mut TxContext): Account {
    Account {
      id: object::new(ctx),
      debt: 0,
      balance: 0
    }
  }  

public fun deposit_to_pool(pool: &mut LiquidityPool, token: Coin<SUI>, ctx: &mut TxContext) {
    let value = coin::value(&token);
    let deposit_value = value - (((value as u128) * FEE /  100) as u64);
    let admin_fee = value - deposit_value;

    let admin_coin = coin::split(&mut token, admin_fee, ctx);
    balance::join(&mut pool.admin_balance, coin::into_balance(admin_coin));
    balance::join(&mut pool.reserves, coin::into_balance(token));

    pool.total_supply = pool.total_supply + deposit_value;
}

public fun withdraw_from_pool(pool: &mut LiquidityPool, value: u64, ctx: &mut TxContext): Coin<SUI> {
    assert!(pool.reserves >= value, ENotEnoughBalance);

    pool.reserves = pool.reserves - value;
    pool.total_supply = pool.total_supply - value;

    coin::from_balance(balance::split(&mut pool.reserves, value), ctx)
}

  public fun destroy_empty_account(account: Account) {
    let Account { id, debt: _, balance} = account;
    assert!(balance == 0, EAccountMustBeEmpty);
    object::delete(id);
  }    

  // === Voting Logic ===

public fun cast_vote(pool: &mut LiquidityPool, voter: address, weight: u64, choice: bool, ctx: &mut TxContext) {
    // Check if the voter has enough stake in the pool
    let stake = get_stake(pool, voter);
    assert!(stake >= weight, EInsufficientStake);

    // Record the vote
    let vote = Vote { voter, weight, choice };
    pool.votes.push(vote);
}


  // === Public-View Functions ===

  public fun balance(self: &Bank): u64 {
    balance::value(&self.balance)
  }

  public fun admin_balance(self: &Bank): u64 {
    balance::value(&self.admin_balance)
  }

  public fun debt(account: &Account): u64 {
    account.debt
  } 

  public fun account_balance(account: &Account): u64 {
    account.balance
  }    

  // === Admin Functions ===

  public fun claim(_: &OwnerCap, self: &mut Bank, ctx: &mut TxContext): Coin<SUI> {
    let value = balance::value(&self.admin_balance);
    coin::take(&mut self.admin_balance, value, ctx)
  }      

  // === Public-Friend Functions ===
  
  public(friend) fun balance_mut(self: &mut Bank): &mut Balance<SUI> {
    &mut self.balance
  }

  public(friend) fun admin_balance_mut(self: &mut Bank): &mut Balance<SUI> {
    &mut self.admin_balance
  }

  public(friend) fun debt_mut(acc: &mut Account): &mut u64 {
    &mut acc.debt
  }  

  public(friend) fun account_balance_mut(acc: &mut Account): &mut u64 {
    &mut acc.balance
  }    

  // === Test Functions ===

  #[test_only]
  public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
  }
}
