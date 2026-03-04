import { vi } from 'vitest'
import { createHash } from 'node:crypto'

// Mock jose
vi.mock('jose', () => ({
  decodeProtectedHeader: vi.fn(),
  importJWK: vi.fn(),
  jwtVerify: vi.fn(),
}))

// Mock plaid
vi.mock('../../src/lib/plaid.js', () => ({
  plaid: {
    webhookVerificationKeyGet: vi.fn(),
  },
}))

import { verifyPlaidWebhook } from '../../src/lib/webhook-verify.js'
import { decodeProtectedHeader, importJWK, jwtVerify } from 'jose'
import { plaid } from '../../src/lib/plaid.js'

const mockDecodeHeader = decodeProtectedHeader as ReturnType<typeof vi.fn>
const mockImportJWK = importJWK as ReturnType<typeof vi.fn>
const mockJwtVerify = jwtVerify as ReturnType<typeof vi.fn>
const mockKeyGet = (plaid.webhookVerificationKeyGet as ReturnType<typeof vi.fn>)

function setupValid(body: string) {
  const bodyHash = createHash('sha256').update(body).digest('hex')
  const now = Math.floor(Date.now() / 1000)

  mockDecodeHeader.mockReturnValue({ kid: 'key-1' })
  mockKeyGet.mockResolvedValue({ data: { key: { kty: 'EC' } } })
  mockImportJWK.mockResolvedValue('imported-key')
  mockJwtVerify.mockResolvedValue({
    payload: { iat: now, request_body_sha256: bodyHash },
  })
}

describe('verifyPlaidWebhook', () => {
  const body = '{"webhook_type":"TRANSACTIONS"}'

  it('passes on valid signature with correct body hash', async () => {
    setupValid(body)
    await expect(verifyPlaidWebhook(body, 'jwt-token')).resolves.toBeUndefined()
    expect(mockDecodeHeader).toHaveBeenCalledWith('jwt-token')
    expect(mockKeyGet).toHaveBeenCalledWith({ key_id: 'key-1' })
  })

  it('throws 401 on missing kid in JWT header', async () => {
    mockDecodeHeader.mockReturnValue({}) // no kid

    await expect(verifyPlaidWebhook(body, 'jwt-token')).rejects.toEqual({
      statusCode: 401,
      message: 'Missing key ID in webhook JWT header',
    })
  })

  it('throws 401 on missing iat claim', async () => {
    mockDecodeHeader.mockReturnValue({ kid: 'key-1' })
    mockKeyGet.mockResolvedValue({ data: { key: { kty: 'EC' } } })
    mockImportJWK.mockResolvedValue('imported-key')
    mockJwtVerify.mockResolvedValue({
      payload: { request_body_sha256: 'abc' }, // no iat
    })

    await expect(verifyPlaidWebhook(body, 'jwt-token')).rejects.toEqual({
      statusCode: 401,
      message: 'Missing iat claim in webhook JWT',
    })
  })

  it('throws 401 on expired JWT (iat > 5 minutes old)', async () => {
    const oldIat = Math.floor(Date.now() / 1000) - 6 * 60 // 6 minutes ago

    mockDecodeHeader.mockReturnValue({ kid: 'key-1' })
    mockKeyGet.mockResolvedValue({ data: { key: { kty: 'EC' } } })
    mockImportJWK.mockResolvedValue('imported-key')
    mockJwtVerify.mockResolvedValue({
      payload: { iat: oldIat, request_body_sha256: 'abc' },
    })

    await expect(verifyPlaidWebhook(body, 'jwt-token')).rejects.toEqual({
      statusCode: 401,
      message: 'Webhook JWT is too old',
    })
  })

  it('throws 401 on body hash mismatch', async () => {
    const now = Math.floor(Date.now() / 1000)

    mockDecodeHeader.mockReturnValue({ kid: 'key-1' })
    mockKeyGet.mockResolvedValue({ data: { key: { kty: 'EC' } } })
    mockImportJWK.mockResolvedValue('imported-key')
    mockJwtVerify.mockResolvedValue({
      payload: { iat: now, request_body_sha256: 'wrong-hash' },
    })

    await expect(verifyPlaidWebhook(body, 'jwt-token')).rejects.toEqual({
      statusCode: 401,
      message: 'Webhook body hash mismatch',
    })
  })
})
