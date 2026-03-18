import { vi } from 'vitest'
import Fastify from 'fastify'
import { createChain } from '../helpers/supabase-chain.js'

// Mock all external dependencies at module level
vi.mock('../../src/lib/supabase.js', () => ({
  supabase: {
    from: vi.fn(),
    auth: { getUser: vi.fn() },
  },
}))

vi.mock('../../src/lib/plaid.js', () => ({
  plaid: {
    linkTokenCreate: vi.fn(),
    itemPublicTokenExchange: vi.fn(),
    accountsGet: vi.fn(),
    transactionsSync: vi.fn(),
  },
}))

import { linkRoutes } from '../../src/routes/link.js'
import { exchangeRoutes } from '../../src/routes/exchange.js'
import { syncRoutes } from '../../src/routes/sync.js'
import { supabase } from '../../src/lib/supabase.js'
import { plaid } from '../../src/lib/plaid.js'

const mockFrom = supabase.from as ReturnType<typeof vi.fn>
const mockGetUser = supabase.auth.getUser as ReturnType<typeof vi.fn>
const mockLinkCreate = plaid.linkTokenCreate as ReturnType<typeof vi.fn>
const mockExchange = plaid.itemPublicTokenExchange as ReturnType<typeof vi.fn>
const mockAccountsGet = plaid.accountsGet as ReturnType<typeof vi.fn>
const mockTxnSync = plaid.transactionsSync as ReturnType<typeof vi.fn>

async function buildFullApp() {
  const app = Fastify({ logger: false })
  app.register(linkRoutes, { prefix: '/link' })
  app.register(exchangeRoutes, { prefix: '/exchange' })
  app.register(syncRoutes, { prefix: '/sync' })
  await app.ready()
  return app
}

describe('Full flow: link → exchange → sync', () => {
  it('completes the entire linking and sync flow', async () => {
    const AUTH_HEADER = 'Bearer valid-token'
    const USER_ID = 'user-flow-1'
    const ACCESS_TOKEN = 'access-tok-flow'
    const PLAID_ITEM_ID = 'plaid-item-flow'
    const INTERNAL_ITEM_ID = 'internal-item-flow'

    // Auth mock — shared across all steps
    mockGetUser.mockResolvedValue({
      data: { user: { id: USER_ID } },
      error: null,
    })

    // --- Step 1: Link token ---
    mockLinkCreate.mockResolvedValue({
      data: { link_token: 'link-tok-flow' },
    })

    const app = await buildFullApp()

    const linkRes = await app.inject({
      method: 'POST',
      url: '/link/token',
      headers: { authorization: AUTH_HEADER },
    })

    expect(linkRes.statusCode).toBe(200)
    expect(linkRes.json()).toEqual({ link_token: 'link-tok-flow' })

    // --- Step 2: Exchange ---
    mockExchange.mockResolvedValue({
      data: { access_token: ACCESS_TOKEN, item_id: PLAID_ITEM_ID },
    })

    const insertChain = createChain({ data: { id: INTERNAL_ITEM_ID }, error: null })
    const syncItemChain = createChain({
      data: { access_token: ACCESS_TOKEN, cursor: null, user_id: USER_ID },
      error: null,
    })
    const exchangeCursorChain = createChain({ data: null, error: null })
    const accountsUpsertChain = createChain({ data: null, error: null })
    const exchangeTxnChain = createChain({ data: null, error: null })
    exchangeTxnChain.upsert = vi.fn().mockReturnValue(createChain({ data: null, error: null }))

    let exchangePlaidItemsCalls = 0
    mockFrom.mockImplementation((table: string) => {
      if (table === 'plaid_items') {
        exchangePlaidItemsCalls++
        // 1st: exchange insert, 2nd: syncTransactions select, 3rd+: cursor update
        if (exchangePlaidItemsCalls === 1) return insertChain
        if (exchangePlaidItemsCalls === 2) return syncItemChain
        return exchangeCursorChain
      }
      if (table === 'accounts') return accountsUpsertChain
      if (table === 'transactions') return exchangeTxnChain
      return createChain({ data: null, error: null })
    })

    mockAccountsGet.mockResolvedValue({
      data: {
        accounts: [
          {
            account_id: 'plaid-acc-flow',
            name: 'Checking',
            official_name: 'Flow Checking',
            type: 'depository',
            subtype: 'checking',
            mask: '9999',
            balances: { current: 2000, available: 1800, iso_currency_code: 'USD' },
          },
        ],
      },
    })

    mockTxnSync.mockResolvedValue({
      data: {
        added: [{
          account_id: 'plaid-acc-flow',
          transaction_id: 'txn-exchange-1',
          name: 'Exchange Coffee',
          amount: 3.5,
          iso_currency_code: 'USD',
          category: ['Food'],
          date: '2024-02-01',
          pending: false,
        }],
        modified: [],
        removed: [],
        next_cursor: 'exchange-cursor-1',
        has_more: false,
      },
    })

    const exchangeRes = await app.inject({
      method: 'POST',
      url: '/exchange',
      headers: { authorization: AUTH_HEADER },
      payload: {
        public_token: 'public-tok-flow',
        institution: { name: 'Flow Bank', institution_id: 'ins_flow' },
      },
    })

    expect(exchangeRes.statusCode).toBe(200)
    expect(exchangeRes.json()).toEqual({ success: true, plaid_item_id: INTERNAL_ITEM_ID })

    // --- Step 3: Sync ---
    // Reconfigure mocks for sync route
    const selectItemChain = createChain({ data: { id: INTERNAL_ITEM_ID }, error: null })
    const plaidItemDetailChain = createChain({
      data: { access_token: ACCESS_TOKEN, cursor: null, user_id: USER_ID },
      error: null,
    })
    const accountsSelectChain = createChain({
      data: [{ id: 'acc-int-flow', plaid_account_id: 'plaid-acc-flow' }],
      error: null,
    })
    const txnChain = createChain({ data: null, error: null })
    txnChain.upsert = vi.fn().mockReturnValue(createChain({ data: null, error: null }))
    const cursorUpdateChain = createChain({ data: null, error: null })
    const balanceUpdateChain = createChain({ data: null, error: null })

    let plaidItemsCalls = 0
    let accountsCalls = 0
    mockFrom.mockImplementation((table: string) => {
      if (table === 'plaid_items') {
        plaidItemsCalls++
        // First call from sync route (ownership check), second from syncTransactions (detail fetch), third is cursor update
        if (plaidItemsCalls <= 2) return plaidItemsCalls === 1 ? selectItemChain : plaidItemDetailChain
        return cursorUpdateChain
      }
      if (table === 'accounts') {
        accountsCalls++
        if (accountsCalls === 1) return accountsSelectChain
        return balanceUpdateChain
      }
      if (table === 'transactions') return txnChain
      return createChain({ data: null, error: null })
    })

    mockTxnSync.mockResolvedValue({
      data: {
        added: [
          {
            account_id: 'plaid-acc-flow',
            transaction_id: 'txn-flow-1',
            name: 'Integration Coffee',
            amount: 3.5,
            iso_currency_code: 'USD',
            category: ['Food'],
            date: '2024-02-01',
            pending: false,
          },
        ],
        modified: [],
        removed: [],
        next_cursor: 'flow-cursor-1',
        has_more: false,
      },
    })

    const syncRes = await app.inject({
      method: 'POST',
      url: '/sync',
      headers: { authorization: AUTH_HEADER },
      payload: { plaid_item_id: INTERNAL_ITEM_ID },
    })

    expect(syncRes.statusCode).toBe(200)
    expect(syncRes.json()).toEqual({ success: true })

    // --- Step 4: Unauthenticated request ---
    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: { message: 'bad token' },
    })

    const unauthRes = await app.inject({
      method: 'POST',
      url: '/link/token',
      headers: { authorization: 'Bearer bad-token' },
    })

    expect(unauthRes.statusCode).toBe(401)
  })
})
