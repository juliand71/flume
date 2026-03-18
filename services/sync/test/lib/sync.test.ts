import { vi } from 'vitest'
import { createChain, createTableRouter } from '../helpers/supabase-chain.js'

vi.mock('../../src/lib/supabase.js', () => ({
  supabase: { from: vi.fn() },
}))

vi.mock('../../src/lib/plaid.js', () => ({
  plaid: {
    transactionsSync: vi.fn(),
    accountsGet: vi.fn(),
  },
}))

import { syncTransactions } from '../../src/lib/sync.js'
import { supabase } from '../../src/lib/supabase.js'
import { plaid } from '../../src/lib/plaid.js'

const mockFrom = supabase.from as ReturnType<typeof vi.fn>
const mockTxnSync = plaid.transactionsSync as ReturnType<typeof vi.fn>
const mockAccountsGet = plaid.accountsGet as ReturnType<typeof vi.fn>

function setupDefaults(overrides: {
  item?: any
  itemError?: any
  accounts?: any[]
  upsertError?: any
  deleteError?: any
  cursorError?: any
} = {}) {
  const plaidItemChain = createChain({
    data: overrides.item ?? {
      access_token: 'access-tok',
      cursor: 'cur-1',
      user_id: 'user-1',
    },
    error: overrides.itemError ?? null,
  })

  const accountsSelectChain = createChain({
    data: overrides.accounts ?? [
      { id: 'acc-int-1', plaid_account_id: 'plaid-acc-1' },
    ],
    error: null,
  })

  const txnUpsertChain = createChain({ data: null, error: overrides.upsertError ?? null })
  const txnDeleteChain = createChain({ data: null, error: overrides.deleteError ?? null })
  const cursorUpdateChain = createChain({ data: null, error: overrides.cursorError ?? null })
  const balanceUpdateChain = createChain({ data: null, error: null })

  // Track call order to distinguish between different from('plaid_items') calls
  let plaidItemsCallCount = 0

  mockFrom.mockImplementation((table: string) => {
    if (table === 'plaid_items') {
      plaidItemsCallCount++
      // First call is the select, subsequent are cursor updates
      if (plaidItemsCallCount === 1) return plaidItemChain
      return cursorUpdateChain
    }
    if (table === 'accounts') {
      // The select for account map vs balance update
      // We use the chain's method calls to distinguish, but for simplicity
      // return a combined chain
      return accountsSelectChain
    }
    if (table === 'transactions') {
      // Need to distinguish upsert vs delete — use a proxy
      const combined = createChain({ data: null, error: null })
      combined.upsert = vi.fn().mockReturnValue(
        createChain({ data: null, error: overrides.upsertError ?? null })
      )
      combined.delete = vi.fn().mockReturnValue(
        createChain({ data: null, error: overrides.deleteError ?? null })
      )
      return combined
    }
    return createChain({ data: null, error: null })
  })

  // Default Plaid mocks
  mockTxnSync.mockResolvedValue({
    data: {
      added: [
        {
          account_id: 'plaid-acc-1',
          transaction_id: 'txn-1',
          name: 'Coffee',
          amount: 4.5,
          iso_currency_code: 'USD',
          category: ['Food'],
          date: '2024-01-15',
          pending: false,
        },
      ],
      modified: [],
      removed: [],
      next_cursor: 'cur-2',
      has_more: false,
    },
  })

  mockAccountsGet.mockResolvedValue({
    data: {
      accounts: [
        {
          account_id: 'plaid-acc-1',
          balances: { current: 1000, available: 900 },
        },
      ],
    },
  })

  return { plaidItemChain, accountsSelectChain, txnUpsertChain, txnDeleteChain, cursorUpdateChain }
}

describe('syncTransactions', () => {
  it('syncs added transactions and updates balances', async () => {
    setupDefaults()
    await syncTransactions('item-1')

    expect(mockTxnSync).toHaveBeenCalledWith({
      access_token: 'access-tok',
      cursor: 'cur-1',
    })
    expect(mockAccountsGet).toHaveBeenCalledWith({ access_token: 'access-tok' })
  })

  it('syncs modified transactions via upsert', async () => {
    setupDefaults()
    mockTxnSync.mockResolvedValue({
      data: {
        added: [],
        modified: [
          {
            account_id: 'plaid-acc-1',
            transaction_id: 'txn-1',
            name: 'Updated Coffee',
            amount: 5.0,
            iso_currency_code: 'USD',
            category: ['Food'],
            date: '2024-01-15',
            pending: false,
          },
        ],
        removed: [],
        next_cursor: 'cur-3',
        has_more: false,
      },
    })

    await syncTransactions('item-1')
    // If it didn't throw, upsert succeeded
    expect(mockTxnSync).toHaveBeenCalled()
  })

  it('deletes removed transactions', async () => {
    setupDefaults()
    mockTxnSync.mockResolvedValue({
      data: {
        added: [],
        modified: [],
        removed: [{ transaction_id: 'txn-del-1' }],
        next_cursor: 'cur-4',
        has_more: false,
      },
    })

    await syncTransactions('item-1')
    expect(mockTxnSync).toHaveBeenCalled()
  })

  it('handles pagination (has_more loop — two pages)', async () => {
    setupDefaults()
    mockTxnSync
      .mockResolvedValueOnce({
        data: {
          added: [
            {
              account_id: 'plaid-acc-1',
              transaction_id: 'txn-p1',
              name: 'Page 1',
              amount: 1,
              iso_currency_code: 'USD',
              category: [],
              date: '2024-01-01',
              pending: false,
            },
          ],
          modified: [],
          removed: [],
          next_cursor: 'page-2-cursor',
          has_more: true,
        },
      })
      .mockResolvedValueOnce({
        data: {
          added: [
            {
              account_id: 'plaid-acc-1',
              transaction_id: 'txn-p2',
              name: 'Page 2',
              amount: 2,
              iso_currency_code: 'USD',
              category: [],
              date: '2024-01-02',
              pending: false,
            },
          ],
          modified: [],
          removed: [],
          next_cursor: 'final-cursor',
          has_more: false,
        },
      })

    await syncTransactions('item-1')
    expect(mockTxnSync).toHaveBeenCalledTimes(2)
    expect(mockTxnSync).toHaveBeenNthCalledWith(1, {
      access_token: 'access-tok',
      cursor: 'cur-1',
    })
    expect(mockTxnSync).toHaveBeenNthCalledWith(2, {
      access_token: 'access-tok',
      cursor: 'page-2-cursor',
    })
  })

  it('passes undefined cursor on first sync (cursor is null)', async () => {
    setupDefaults({
      item: { access_token: 'access-tok', cursor: null, user_id: 'user-1' },
    })

    await syncTransactions('item-1')
    expect(mockTxnSync).toHaveBeenCalledWith({
      access_token: 'access-tok',
    })
  })

  it('updates account balances after sync completes', async () => {
    setupDefaults()
    await syncTransactions('item-1')

    expect(mockAccountsGet).toHaveBeenCalledWith({ access_token: 'access-tok' })
    // Verify from('accounts') was called for balance update
    expect(mockFrom).toHaveBeenCalledWith('accounts')
  })

  it('throws 404 when plaid item not found', async () => {
    setupDefaults({ item: null, itemError: { message: 'not found' } })

    await expect(syncTransactions('missing-item')).rejects.toEqual({
      statusCode: 404,
      message: 'Plaid item not found',
    })
  })

  it('throws 500 on transaction upsert failure', async () => {
    setupDefaults({ upsertError: { message: 'upsert failed' } })

    await expect(syncTransactions('item-1')).rejects.toEqual({
      statusCode: 500,
      message: 'Failed to upsert transactions: upsert failed',
    })
  })

  it('throws 500 on transaction delete failure', async () => {
    setupDefaults({ deleteError: { message: 'delete failed' } })
    mockTxnSync.mockResolvedValue({
      data: {
        added: [],
        modified: [],
        removed: [{ transaction_id: 'txn-del' }],
        next_cursor: 'cur-x',
        has_more: false,
      },
    })

    await expect(syncTransactions('item-1')).rejects.toEqual({
      statusCode: 500,
      message: 'Failed to delete transactions: delete failed',
    })
  })

  it('throws 500 on cursor update failure', async () => {
    setupDefaults({ cursorError: { message: 'cursor failed' } })

    await expect(syncTransactions('item-1')).rejects.toEqual({
      statusCode: 500,
      message: 'Failed to update cursor: cursor failed',
    })
  })
})
