import { vi } from 'vitest'
import type { FastifyRequest } from 'fastify'

// Mock the supabase singleton
vi.mock('../../src/lib/supabase.js', () => ({
  supabase: {
    auth: {
      getUser: vi.fn(),
    },
  },
}))

import { authenticateUser } from '../../src/lib/auth.js'
import { supabase } from '../../src/lib/supabase.js'

function fakeRequest(authHeader?: string): FastifyRequest {
  return {
    headers: {
      ...(authHeader !== undefined ? { authorization: authHeader } : {}),
    },
  } as unknown as FastifyRequest
}

describe('authenticateUser', () => {
  it('returns user ID on valid Bearer token', async () => {
    const mockGetUser = supabase.auth.getUser as ReturnType<typeof vi.fn>
    mockGetUser.mockResolvedValue({
      data: { user: { id: 'user-123' } },
      error: null,
    })

    const userId = await authenticateUser(fakeRequest('Bearer valid-token'))
    expect(userId).toBe('user-123')
    expect(mockGetUser).toHaveBeenCalledWith('valid-token')
  })

  it('throws 401 on missing Authorization header', async () => {
    await expect(authenticateUser(fakeRequest())).rejects.toEqual({
      statusCode: 401,
      message: 'Missing or invalid Authorization header',
    })
  })

  it('throws 401 on malformed header (no "Bearer " prefix)', async () => {
    await expect(authenticateUser(fakeRequest('Basic abc'))).rejects.toEqual({
      statusCode: 401,
      message: 'Missing or invalid Authorization header',
    })
  })

  it('throws 401 when Supabase returns error', async () => {
    const mockGetUser = supabase.auth.getUser as ReturnType<typeof vi.fn>
    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: { message: 'bad token' },
    })

    await expect(authenticateUser(fakeRequest('Bearer bad'))).rejects.toEqual({
      statusCode: 401,
      message: 'Invalid token',
    })
  })

  it('throws 401 when user is null', async () => {
    const mockGetUser = supabase.auth.getUser as ReturnType<typeof vi.fn>
    mockGetUser.mockResolvedValue({
      data: { user: null },
      error: null,
    })

    await expect(authenticateUser(fakeRequest('Bearer orphan'))).rejects.toEqual({
      statusCode: 401,
      message: 'Invalid token',
    })
  })
})
