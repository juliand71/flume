import { vi } from 'vitest'
import Fastify from 'fastify'
import { createChain } from '../helpers/supabase-chain.js'

vi.mock('../../src/lib/auth.js', () => ({
  authenticateUser: vi.fn(),
}))

vi.mock('../../src/lib/plaid.js', () => ({
  plaid: {
    itemPublicTokenExchange: vi.fn(),
    accountsGet: vi.fn(),
    transactionsSync: vi.fn(),
  },
}))

vi.mock('../../src/lib/supabase.js', () => ({
  supabase: { from: vi.fn() },
}))

import { exchangeRoutes } from '../../src/routes/exchange.js'
import { authenticateUser } from '../../src/lib/auth.js'
import { plaid } from '../../src/lib/plaid.js'
import { supabase } from '../../src/lib/supabase.js'

const mockAuth = authenticateUser as ReturnType<typeof vi.fn>
const mockExchange = plaid.itemPublicTokenExchange as ReturnType<typeof vi.fn>
const mockAccountsGet = plaid.accountsGet as ReturnType<typeof vi.fn>
const mockTxnSync = plaid.transactionsSync as ReturnType<typeof vi.fn>
const mockFrom = supabase.from as ReturnType<typeof vi.fn>

const validBody = {
  public_token: 'public-tok',
  institution: { name: 'Chase', institution_id: 'ins_1' },
}

async function buildApp() {
  const app = Fastify({ logger: false })
  app.register(exchangeRoutes, { prefix: '/exchange' })
  await app.ready()
  return app
}

function setupHappyPath(accountType = 'depository', accountSubtype = 'checking') {
  mockAuth.mockResolvedValue('user-1')
  mockExchange.mockResolvedValue({
    data: { access_token: 'access-tok', item_id: 'plaid-item-1' },
  })

  // Exchange inserts plaid_item, then syncTransactions reads it back + updates cursor
  const insertChain = createChain({ data: { id: 'internal-item-1' }, error: null })
  const syncItemChain = createChain({
    data: { access_token: 'access-tok', cursor: null, user_id: 'user-1' },
    error: null,
  })
  const cursorUpdateChain = createChain({ data: null, error: null })
  // accounts upsert now selects back id/type/subtype for role assignment
  const upsertChain = createChain({
    data: [{ id: 'acct-1', type: accountType, subtype: accountSubtype }],
    error: null,
  })
  const rolesChain = createChain({ data: null, error: null })
  const txnChain = createChain({ data: null, error: null })
  txnChain.upsert = vi.fn().mockReturnValue(createChain({ data: null, error: null }))

  let plaidItemsCalls = 0
  mockFrom.mockImplementation((table: string) => {
    if (table === 'plaid_items') {
      plaidItemsCalls++
      // 1st: exchange insert, 2nd: syncTransactions select, 3rd+: cursor update
      if (plaidItemsCalls === 1) return insertChain
      if (plaidItemsCalls === 2) return syncItemChain
      return cursorUpdateChain
    }
    if (table === 'accounts') return upsertChain
    if (table === 'account_roles') return rolesChain
    if (table === 'transactions') return txnChain
    return createChain({ data: null, error: null })
  })

  mockAccountsGet.mockResolvedValue({
    data: {
      accounts: [
        {
          account_id: 'plaid-acc-1',
          name: 'Checking',
          official_name: 'Chase Checking',
          type: accountType,
          subtype: accountSubtype,
          mask: '1234',
          balances: { current: 5000, available: 4800, iso_currency_code: 'USD' },
        },
      ],
    },
  })

  mockTxnSync.mockResolvedValue({
    data: {
      added: [{
        account_id: 'plaid-acc-1',
        transaction_id: 'txn-1',
        name: 'Coffee',
        amount: 4.5,
        iso_currency_code: 'USD',
        category: ['Food'],
        date: '2024-01-15',
        pending: false,
      }],
      modified: [],
      removed: [],
      next_cursor: 'cur-1',
      has_more: false,
    },
  })

  return { rolesChain }
}

describe('POST /exchange', () => {
  it('returns { success: true, plaid_item_id } on full happy path', async () => {
    setupHappyPath()
    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ success: true, plaid_item_id: 'internal-item-1' })
  })

  it('assigns checking role for depository/checking account', async () => {
    const { rolesChain } = setupHappyPath('depository', 'checking')
    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/exchange', payload: validBody })

    expect(rolesChain.upsert).toHaveBeenCalledWith(
      [{ account_id: 'acct-1', user_id: 'user-1', account_role: 'checking' }],
      { onConflict: 'account_id' }
    )
  })

  it('assigns savings role for depository/savings account', async () => {
    const { rolesChain } = setupHappyPath('depository', 'savings')
    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/exchange', payload: validBody })

    expect(rolesChain.upsert).toHaveBeenCalledWith(
      [{ account_id: 'acct-1', user_id: 'user-1', account_role: 'savings' }],
      { onConflict: 'account_id' }
    )
  })

  it('assigns credit_card role for credit account', async () => {
    const { rolesChain } = setupHappyPath('credit', 'credit card')
    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/exchange', payload: validBody })

    expect(rolesChain.upsert).toHaveBeenCalledWith(
      [{ account_id: 'acct-1', user_id: 'user-1', account_role: 'credit_card' }],
      { onConflict: 'account_id' }
    )
  })

  it('skips role assignment for unsupported account types', async () => {
    const { rolesChain } = setupHappyPath('investment', 'brokerage')
    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/exchange', payload: validBody })

    expect(rolesChain.upsert).not.toHaveBeenCalled()
  })

  it('returns 400 on missing public_token', async () => {
    mockAuth.mockResolvedValue('user-1')
    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: { institution: { name: 'Chase' } },
    })

    expect(res.statusCode).toBe(400)
    expect(res.json()).toEqual({ error: 'Missing public_token or institution' })
  })

  it('returns 400 on missing institution', async () => {
    mockAuth.mockResolvedValue('user-1')
    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: { public_token: 'tok' },
    })

    expect(res.statusCode).toBe(400)
    expect(res.json()).toEqual({ error: 'Missing public_token or institution' })
  })

  it('returns 401 when unauthenticated', async () => {
    mockAuth.mockRejectedValue({ statusCode: 401, message: 'Missing or invalid Authorization header' })
    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(401)
  })

  it('returns 500 on Plaid exchange error', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockExchange.mockRejectedValue(new Error('Plaid exchange failed'))

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'Plaid exchange failed' })
  })

  it('returns 500 on plaid_items insert failure', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockExchange.mockResolvedValue({
      data: { access_token: 'access-tok', item_id: 'plaid-item-1' },
    })
    mockFrom.mockReturnValue(
      createChain({ data: null, error: { message: 'insert failed' } })
    )

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'Failed to store plaid item: insert failed' })
  })

  it('returns 500 on accounts upsert failure', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockExchange.mockResolvedValue({
      data: { access_token: 'access-tok', item_id: 'plaid-item-1' },
    })

    const insertChain = createChain({ data: { id: 'internal-item-1' }, error: null })
    const upsertChain = createChain({ data: null, error: { message: 'accounts upsert failed' } })

    mockFrom.mockImplementation((table: string) => {
      if (table === 'plaid_items') return insertChain
      if (table === 'accounts') return upsertChain
      return createChain({ data: null, error: null })
    })

    mockAccountsGet.mockResolvedValue({
      data: { accounts: [{ account_id: 'a', name: 'X', official_name: null, type: 'depository', subtype: 'checking', mask: '0000', balances: { current: 0, available: 0, iso_currency_code: 'USD' } }] },
    })

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'Failed to store accounts: accounts upsert failed' })
  })

  it('returns 500 on account_roles upsert failure', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockExchange.mockResolvedValue({
      data: { access_token: 'access-tok', item_id: 'plaid-item-1' },
    })

    const insertChain = createChain({ data: { id: 'internal-item-1' }, error: null })
    const upsertChain = createChain({ data: [{ id: 'acct-1', type: 'depository', subtype: 'checking' }], error: null })
    const rolesChain = createChain({ data: null, error: { message: 'roles upsert failed' } })

    mockFrom.mockImplementation((table: string) => {
      if (table === 'plaid_items') return insertChain
      if (table === 'accounts') return upsertChain
      if (table === 'account_roles') return rolesChain
      return createChain({ data: null, error: null })
    })

    mockAccountsGet.mockResolvedValue({
      data: { accounts: [{ account_id: 'a', name: 'X', official_name: null, type: 'depository', subtype: 'checking', mask: '0000', balances: { current: 0, available: 0, iso_currency_code: 'USD' } }] },
    })

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/exchange',
      payload: validBody,
    })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'Failed to store account roles: roles upsert failed' })
  })
})
