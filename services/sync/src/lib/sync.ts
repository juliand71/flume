import { plaid } from './plaid.js'
import { supabase } from './supabase.js'

interface TransactionRow {
  account_id: string | undefined
  user_id: string
  plaid_transaction_id: string
  name: string
  amount: number
  iso_currency_code: string
  category: string[] | null
  date: string
  pending: boolean
  personal_finance_category: object | null
}

export async function syncTransactions(plaidItemInternalId: string) {
  // Fetch the plaid item to get access_token, cursor, and user_id
  const { data: item, error: itemError } = await supabase
    .from('plaid_items')
    .select('access_token, cursor, user_id')
    .eq('id', plaidItemInternalId)
    .single()

  if (itemError || !item) {
    throw { statusCode: 404, message: 'Plaid item not found' }
  }

  // Build a lookup map of plaid_account_id -> our internal account id
  const { data: accounts } = await supabase
    .from('accounts')
    .select('id, plaid_account_id')
    .eq('plaid_item_id', plaidItemInternalId)

  const accountMap = new Map(
    (accounts ?? []).map((a) => [a.plaid_account_id, a.id])
  )

  let cursor = item.cursor ?? undefined
  let hasMore = true

  while (hasMore) {
    const response = await plaid.transactionsSync({
      access_token: item.access_token,
      ...(cursor ? { cursor } : {}),
    })

    const { added, modified, removed, next_cursor, has_more } = response.data

    // Upsert added + modified transactions
    const toUpsert = [...added, ...modified]
    if (toUpsert.length > 0) {
      const rows: TransactionRow[] = toUpsert.map((txn) => ({
        account_id: accountMap.get(txn.account_id),
        user_id: item.user_id,
        plaid_transaction_id: txn.transaction_id,
        name: txn.name,
        amount: txn.amount,
        iso_currency_code: txn.iso_currency_code ?? 'USD',
        category: txn.category,
        date: txn.date,
        pending: txn.pending,
        personal_finance_category: txn.personal_finance_category ?? null,
      }))

      const { error: upsertError } = await supabase
        .from('transactions')
        .upsert(rows, { onConflict: 'plaid_transaction_id' })

      if (upsertError) {
        throw { statusCode: 500, message: `Failed to upsert transactions: ${upsertError.message}` }
      }
    }

    // Delete removed transactions
    if (removed.length > 0) {
      const removedIds = removed.map((r) => r.transaction_id)
      const { error: deleteError } = await supabase
        .from('transactions')
        .delete()
        .in('plaid_transaction_id', removedIds)

      if (deleteError) {
        throw { statusCode: 500, message: `Failed to delete transactions: ${deleteError.message}` }
      }
    }

    // Update cursor
    cursor = next_cursor
    const { error: cursorError } = await supabase
      .from('plaid_items')
      .update({ cursor: next_cursor })
      .eq('id', plaidItemInternalId)

    if (cursorError) {
      throw { statusCode: 500, message: `Failed to update cursor: ${cursorError.message}` }
    }

    hasMore = has_more
  }

  // Update account balances
  const balanceResponse = await plaid.accountsGet({
    access_token: item.access_token,
  })

  for (const account of balanceResponse.data.accounts) {
    const { error: balanceError } = await supabase
      .from('accounts')
      .update({
        current_balance: account.balances.current,
        available_balance: account.balances.available,
        updated_at: new Date().toISOString(),
      })
      .eq('plaid_account_id', account.account_id)

    if (balanceError) {
      console.warn(`Failed to update balance for account ${account.account_id}: ${balanceError.message}`)
    }
  }
}
