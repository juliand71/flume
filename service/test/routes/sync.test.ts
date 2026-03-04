import { vi } from 'vitest'
import Fastify from 'fastify'
import { createChain } from '../helpers/supabase-chain.js'

vi.mock('../../src/lib/auth.js', () => ({
  authenticateUser: vi.fn(),
}))

vi.mock('../../src/lib/sync.js', () => ({
  syncTransactions: vi.fn(),
}))

vi.mock('../../src/lib/supabase.js', () => ({
  supabase: { from: vi.fn() },
}))

import { syncRoutes } from '../../src/routes/sync.js'
import { authenticateUser } from '../../src/lib/auth.js'
import { syncTransactions } from '../../src/lib/sync.js'
import { supabase } from '../../src/lib/supabase.js'

const mockAuth = authenticateUser as ReturnType<typeof vi.fn>
const mockSyncTxn = syncTransactions as ReturnType<typeof vi.fn>
const mockFrom = supabase.from as ReturnType<typeof vi.fn>

async function buildApp() {
  const app = Fastify({ logger: false })
  app.register(syncRoutes, { prefix: '/sync' })
  await app.ready()
  return app
}

describe('POST /sync', () => {
  it('returns { success: true } on success', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockFrom.mockReturnValue(createChain({ data: { id: 'item-1' }, error: null }))
    mockSyncTxn.mockResolvedValue(undefined)

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/sync',
      payload: { plaid_item_id: 'item-1' },
    })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ success: true })
    expect(mockSyncTxn).toHaveBeenCalledWith('item-1')
  })

  it('returns 400 on missing plaid_item_id', async () => {
    mockAuth.mockResolvedValue('user-1')

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/sync',
      payload: {},
    })

    expect(res.statusCode).toBe(400)
    expect(res.json()).toEqual({ error: 'Missing plaid_item_id' })
  })

  it('returns 401 when unauthenticated', async () => {
    mockAuth.mockRejectedValue({ statusCode: 401, message: 'Unauthorized' })

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/sync',
      payload: { plaid_item_id: 'item-1' },
    })

    expect(res.statusCode).toBe(401)
  })

  it('returns 404 when item not found or wrong user', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockFrom.mockReturnValue(createChain({ data: null, error: { message: 'not found' } }))

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/sync',
      payload: { plaid_item_id: 'missing-item' },
    })

    expect(res.statusCode).toBe(404)
    expect(res.json()).toEqual({ error: 'Plaid item not found' })
  })

  it('returns 500 when syncTransactions throws', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockFrom.mockReturnValue(createChain({ data: { id: 'item-1' }, error: null }))
    mockSyncTxn.mockRejectedValue({ statusCode: 500, message: 'sync boom' })

    const app = await buildApp()
    const res = await app.inject({
      method: 'POST',
      url: '/sync',
      payload: { plaid_item_id: 'item-1' },
    })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'sync boom' })
  })
})
