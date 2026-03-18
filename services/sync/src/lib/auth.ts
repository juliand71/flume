import type { FastifyRequest } from 'fastify'
import { supabase } from './supabase.js'

export async function authenticateUser(request: FastifyRequest): Promise<string> {
  const authHeader = request.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    throw { statusCode: 401, message: 'Missing or invalid Authorization header' }
  }

  const token = authHeader.slice(7)
  const { data, error } = await supabase.auth.getUser(token)

  if (error || !data.user) {
    throw { statusCode: 401, message: 'Invalid token' }
  }

  return data.user.id
}
