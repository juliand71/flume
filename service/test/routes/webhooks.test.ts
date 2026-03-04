import { vi } from 'vitest'
import Fastify from 'fastify'
import { createChain } from '../helpers/supabase-chain.js'

vi.mock('../../src/lib/webhook-verify.js', () => ({
  verifyPlaidWebhook: vi.fn(),
}))

vi.mock('../../src/lib/sync.js', () => ({
  syncTransactions: vi.fn(),
}))

vi.mock('../../src/lib/supabase.js', () => ({
  supabase: { from: vi.fn() },
}))

import { webhookRoutes } from '../../src/routes/webhooks.js'
import { verifyPlaidWebhook } from '../../src/lib/webhook-verify.js'
import { syncTransactions } from '../../src/lib/sync.js'
import { supabase } from '../../src/lib/supabase.js'

const mockVerify = verifyPlaidWebhook as ReturnType<typeof vi.fn>
const mockSyncTxn = syncTransactions as ReturnType<typeof vi.fn>
const mockFrom = supabase.from as ReturnType<typeof vi.fn>

async function buildApp() {
  const app = Fastify({ logger: false })
  app.register(webhookRoutes, { prefix: '/webhooks' })
  await app.ready()
  return app
}

const txnPayload = {
  webhook_type: 'TRANSACTIONS',
  webhook_code: 'SYNC_UPDATES_AVAILABLE',
  item_id: 'plaid-item-ext',
}

describe('POST /webhooks', () => {
  it('returns { success: true } and triggers sync on valid SYNC_UPDATES_AVAILABLE', async () => {
    mockVerify.mockResolvedValue(undefined)
    mockFrom.mockReturnValue(createChain({ data: { id: 'internal-item-1' }, error: null }))
    mockSyncTxn.mockResolvedValue(undefined)

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: txnPayload,
      headers: { 'plaid-verification': 'valid-jwt' },
    })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ success: true })
    expect(mockSyncTxn).toHaveBeenCalledWith('internal-item-1')
  })

  it('returns 401 on missing Plaid-Verification header', async () => {
    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: txnPayload,
    })

    expect(res.statusCode).toBe(401)
    expect(res.json()).toEqual({ error: 'Missing Plaid-Verification header' })
  })

  it('returns 401 when webhook verification fails', async () => {
    mockVerify.mockRejectedValue({ statusCode: 401, message: 'bad sig' })

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: txnPayload,
      headers: { 'plaid-verification': 'bad-jwt' },
    })

    expect(res.statusCode).toBe(401)
    expect(res.json()).toEqual({ error: 'bad sig' })
  })

  it('ignores non-TRANSACTIONS webhook types (returns 200, no sync)', async () => {
    mockVerify.mockResolvedValue(undefined)

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: { webhook_type: 'ITEM', webhook_code: 'ERROR', item_id: 'x' },
      headers: { 'plaid-verification': 'valid-jwt' },
    })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ success: true })
    expect(mockSyncTxn).not.toHaveBeenCalled()
  })

  it('ignores unrecognized TRANSACTIONS codes (returns 200, no sync)', async () => {
    mockVerify.mockResolvedValue(undefined)

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: { webhook_type: 'TRANSACTIONS', webhook_code: 'REMOVED', item_id: 'x' },
      headers: { 'plaid-verification': 'valid-jwt' },
    })

    expect(res.statusCode).toBe(200)
    expect(mockSyncTxn).not.toHaveBeenCalled()
  })

  it('logs warning when item_id not found in DB (returns 200, no sync)', async () => {
    mockVerify.mockResolvedValue(undefined)
    mockFrom.mockReturnValue(createChain({ data: null, error: { message: 'not found' } }))

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/webhooks',
      payload: txnPayload,
      headers: { 'plaid-verification': 'valid-jwt' },
    })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ success: true })
    expect(mockSyncTxn).not.toHaveBeenCalled()
  })

  it('triggers sync for all recognized codes', async () => {
    mockVerify.mockResolvedValue(undefined)
    mockFrom.mockReturnValue(createChain({ data: { id: 'int-1' }, error: null }))
    mockSyncTxn.mockResolvedValue(undefined)

    const codes = ['DEFAULT_UPDATE', 'INITIAL_UPDATE', 'HISTORICAL_UPDATE']
    const app = await buildApp()

    for (const code of codes) {
      mockSyncTxn.mockClear()
      const res = await app.inject({
        method: 'POST',
        url: '/webhooks',
        payload: { webhook_type: 'TRANSACTIONS', webhook_code: code, item_id: 'ext-1' },
        headers: { 'plaid-verification': 'valid-jwt' },
      })

      expect(res.statusCode).toBe(200)
      expect(mockSyncTxn).toHaveBeenCalledWith('int-1')
    }
  })
})
