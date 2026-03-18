import { vi } from 'vitest'
import Fastify from 'fastify'

vi.mock('../../src/lib/auth.js', () => ({
  authenticateUser: vi.fn(),
}))

vi.mock('../../src/lib/plaid.js', () => ({
  plaid: {
    linkTokenCreate: vi.fn(),
  },
}))

import { linkRoutes } from '../../src/routes/link.js'
import { authenticateUser } from '../../src/lib/auth.js'
import { plaid } from '../../src/lib/plaid.js'

const mockAuth = authenticateUser as ReturnType<typeof vi.fn>
const mockLinkCreate = plaid.linkTokenCreate as ReturnType<typeof vi.fn>

async function buildApp() {
  const app = Fastify({ logger: false })
  app.register(linkRoutes, { prefix: '/link' })
  await app.ready()
  return app
}

describe('POST /link/token', () => {
  it('returns { link_token } on success', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockLinkCreate.mockResolvedValue({ data: { link_token: 'link-tok-123' } })

    const app = await buildApp()
    const res = await app.inject({ method: 'POST', url: '/link/token' })

    expect(res.statusCode).toBe(200)
    expect(res.json()).toEqual({ link_token: 'link-tok-123' })
  })

  it('returns 401 when unauthenticated', async () => {
    mockAuth.mockRejectedValue({ statusCode: 401, message: 'Missing or invalid Authorization header' })

    const app = await buildApp()
    const res = await app.inject({ method: 'POST', url: '/link/token' })

    expect(res.statusCode).toBe(401)
    expect(res.json()).toEqual({ error: 'Missing or invalid Authorization header' })
  })

  it('includes webhook URL when RAILWAY_PUBLIC_DOMAIN is set', async () => {
    process.env.RAILWAY_PUBLIC_DOMAIN = 'myapp.railway.app'
    mockAuth.mockResolvedValue('user-1')
    mockLinkCreate.mockResolvedValue({ data: { link_token: 'link-tok' } })

    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/link/token' })

    expect(mockLinkCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        webhook: 'https://myapp.railway.app/webhooks',
      })
    )
    delete process.env.RAILWAY_PUBLIC_DOMAIN
  })

  it('omits webhook when RAILWAY_PUBLIC_DOMAIN is unset', async () => {
    delete process.env.RAILWAY_PUBLIC_DOMAIN
    mockAuth.mockResolvedValue('user-1')
    mockLinkCreate.mockResolvedValue({ data: { link_token: 'link-tok' } })

    const app = await buildApp()
    await app.inject({ method: 'POST', url: '/link/token' })

    expect(mockLinkCreate).toHaveBeenCalledWith(
      expect.not.objectContaining({ webhook: expect.anything() })
    )
  })

  it('returns 500 on Plaid SDK error', async () => {
    mockAuth.mockResolvedValue('user-1')
    mockLinkCreate.mockRejectedValue(new Error('Plaid is down'))

    const app = await buildApp()
    const res = await app.inject({ method: 'POST', url: '/link/token' })

    expect(res.statusCode).toBe(500)
    expect(res.json()).toEqual({ error: 'Plaid is down' })
  })
})
