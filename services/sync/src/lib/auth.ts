import type { FastifyRequest } from 'fastify'
import { createRemoteJWKSet, jwtVerify } from 'jose'

const supabaseURL = process.env.SUPABASE_URL!
const JWKS = createRemoteJWKSet(new URL(`${supabaseURL}/auth/v1/.well-known/jwks.json`))

export async function authenticateUser(request: FastifyRequest): Promise<string> {
  const authHeader = request.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    throw { statusCode: 401, message: 'Missing or invalid Authorization header' }
  }

  const token = authHeader.slice(7)

  try {
    const { payload } = await jwtVerify(token, JWKS)
    const sub = payload.sub
    if (!sub) throw new Error('missing sub')
    return sub
  } catch {
    throw { statusCode: 401, message: 'Invalid token' }
  }
}
