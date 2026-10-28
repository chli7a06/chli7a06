# Company banking adapters — 3.0.5

Personal citizen balances continue to use Qbox money.bank. Company balances use a server-only adapter. This is not automatic compatibility with every banking product.

## Selection

Config.Banking = { provider='auto', accounts={} }

Auto selection works only when exactly one of Renewed-Banking, qb-banking, apex_banking is started. Apex detection deliberately reports that an adapter is required until its API is verified. More than one detected resource fails clearly rather than silently selecting the wrong ledger. Explicit examples:

```lua
Config.Banking = {
 provider='qb-banking', -- or 'Renewed-Banking'
 accounts={ mechanic='mechanic', burgershot='burgershot' },
}
```

Set the correct provider in your retained config.lua. Existing Config.Integrations.banking is a fallback only if Config.Banking.provider is absent. To disable banking explicitly use provider=false. No client can select a provider, raw export, SQL table or arbitrary company account. Config.BusinessJobs and existing DOJ management checks still apply (default DOJ grade 3). Do not install a second bank just for this resource.

Renewed-Banking: account balance, transaction history, credits, payment history supported. qb-banking: GetAccount/account_balance distinguishes missing from zero; AddMoney returns positive affected rows for success and false for a rejected destination. Zero/nil/exception after credit is uncertain, so payment is locked for review. qb-banking handles its own deposit statements; transaction lists are not implemented here and remain empty. Native versions were inspected; forks require their own verification. Existing durable payment journal and citizen debit/refund behavior remain in place. Provider selection is retained for each settlement; it does not switch banks midway.

## Any other resource with a balance export (read only)

```lua
Config.Banking = {
 provider='custom', resource='YOUR_BANK_RESOURCE',
 balanceExport='THE_DOCUMENTED_BALANCE_EXPORT',
 -- balanceField='balance', -- only if export returns a table
 accounts={mechanic='THE_ACTUAL_COMPANY_ACCOUNT'},
}
```

These are placeholders, not Apex export names. Calls pass a single account name argument. Custom balance export must synchronously return a number/numeric string or table field; nil/false/invalid/nonfinite values display Unavailable, never zero. Callback/event APIs need a server adapter. Generic exports are read-only: invoice/fine settlement rejects before debiting a citizen. No SQL balance writes are used, avoiding provider cache divergence.

For verified custom APIs edit server-only bank_adapters.lua:

```lua
CrimsonBankAdapters['YOUR_BANK_RESOURCE'] = {
 resource='YOUR_BANK_RESOURCE',
 balance=function(account) -- return numeric balance or nil
 end,
 -- transactions=function(account) return {} end,
 -- credit=function(account,amount,reason)
 --   return true -- only for confirmed credit
 --   return false -- only for confirmed rejection without changing funds
 --   error('uncertain') -- outcome unknown; do not retry
 -- end,
}
```

Select that provider explicitly. Never implement credit by blindly returning true or by writing SQL balances directly. Only server administrators edit adapters. Preserve local adapter/config files when updating. Apex support needs its actual SQL/export/bridge files; no Apex schema or API is guessed.

Validation: full local suite plus 17 adapter checks covers zero/missing accounts, resource readiness, ambiguous/no-provider selection, mapping, custom balance fields, read-only custom mode, unknown Apex refusal, credit return semantics. Actual live bank integrations require in-server testing; no production DB or money was touched.
