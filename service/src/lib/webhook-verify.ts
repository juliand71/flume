import { createHash } from 'node:crypto'
import { decodeProtectedHeader, importJWK, jwtVerify } from 'jose'
import { plaid } from './plaid.js'

const MAX_AGE_SECONDS = 5 * 60 // 5 minutes

export async function verifyPlaidWebhook(
  body: string,
  plaidVerificationHeader: string
): Promise<void> {
  // Decode the JWT header to get the key ID
  const { kid } = decodeProtectedHeader(plaidVerificationHeader)
  if (!kid) {
    throw { statusCode: 401, message: 'Missing key ID in webhook JWT header' }
  }

  // Fetch the verification key from Plaid
  const response = await plaid.webhookVerificationKeyGet({ key_id: kid })
  const jwk = response.data.key

  // Import the JWK and verify the JWT signature
  const key = await importJWK(jwk)
  const { payload } = await jwtVerify(plaidVerificationHeader, key, {
    algorithms: ['ES256'],
  })

  // Verify the token is not too old
  const issuedAt = payload.iat
  if (!issuedAt) {
    throw { statusCode: 401, message: 'Missing iat claim in webhook JWT' }
  }
  const now = Math.floor(Date.now() / 1000)
  if (now - issuedAt > MAX_AGE_SECONDS) {
    throw { statusCode: 401, message: 'Webhook JWT is too old' }
  }

  // Verify the body hash matches
  const expectedHash = createHash('sha256').update(body).digest('hex')
  const claimedHash = (payload as any).request_body_sha256
  if (expectedHash !== claimedHash) {
    throw { statusCode: 401, message: 'Webhook body hash mismatch' }
  }
}
