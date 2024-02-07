module sui_bank::lending {
  // === Imports ===

  use sui::coin::Coin;
  use sui::tx_context::TxContext;

  use sui_bank::bank::{Self, Account, Bank};
  use sui_bank::liquidity_pool::LiquidityPool;
  use sui_bank::oracle::{Self, Price};  
  use sui_bank::sui_dollar::{Self, CapWrapper, SUI_DOLLAR};  

  // === Roles ===

  struct AssetManager has key {
    id: UID,
  }

  // === Errors ===

  const EBorrowAmountIsTooHigh: u64 =  0;

  // === Constants ===

  const LTV: u128 =  40;   

  // === Init ===

  public fun init(ctx: &mut TxContext) {
    let asset_manager = AssetManager { id: object::new(ctx) };
    transfer::transfer(asset_manager, tx_context::sender(ctx));
  }

  // === Public-Mutative Functions ===

  public fun borrow(ctx: &mut TxContext, pool: &mut LiquidityPool, account: &mut Account, cap: &mut CapWrapper, price: Price, value: u64): Coin<SUI_DOLLAR> {
    // Check if caller is the AssetManager
    assert!(tx_context::is_sender(ctx, &asset_manager), ENotAuthorized);

    // Calculate the maximum borrowable amount based on the current collateral ratio
    // ... (existing logic to determine max_borrow_amount) ...

    // Withdraw funds from the liquidity pool
    let coin = withdraw_from_pool(pool, value, ctx);

    // Update the account's debt
    let debt_mut = bank::debt_mut(account);
    debt_mut = *debt_mut + value;

    // Mint and return the borrowed SUI Dollars
    sui_dollar::mint(cap, value, ctx)
  }

  public fun repay(ctx: &mut TxContext, pool: &mut LiquidityPool, account: &mut Account, cap: &mut CapWrapper, coin_in: Coin<SUI_DOLLAR>) {
    // Check if caller is the AssetManager
    assert!(tx_context::is_sender(ctx, &asset_manager), ENotAuthorized);

    // Burn the SUI Dollars and update the account's debt
    let amount = sui_dollar::burn(cap, coin_in);
    let debt_mut = bank::debt_mut(account);
    debt_mut = *debt_mut - amount;

    // Deposit the repaid amount back into the liquidity pool
    deposit_to_pool(pool, coin_in, ctx);
  }    
}