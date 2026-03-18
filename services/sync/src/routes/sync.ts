import type { FastifyInstance } from 'fastify'
import { authenticateUser } from '../lib/auth.js'
import { supabase } from '../lib/supabase.js'
import { syncTransactions } from '../lib/sync.js'

interface SyncBody {
  plaid_item_id: string
}

export async function syncRoutes(app: FastifyInstance) {
  // POST /sync — trigger a Plaid transactions/sync for a given item
  app.post('/', async (request, reply) => {
    try {
      const userId = await authenticateUser(request)
      const body = request.body as SyncBody

      if (!body?.plaid_item_id) {
        return reply.status(400).send({ error: 'Missing plaid_item_id' })
      }

      // Verify the item belongs to this user
      const { data: item, error } = await supabase
        .from('plaid_items')
        .select('id')
        .eq('id', body.plaid_item_id)
        .eq('user_id', userId)
        .single()

      if (error || !item) {
        return reply.status(404).send({ error: 'Plaid item not found' })
      }

      await syncTransactions(body.plaid_item_id)

      return { success: true }
    } catch (err: any) {
      const status = err.statusCode ?? 500
      request.log.error(err)
      return reply.status(status).send({ error: err.message ?? 'Internal server error' })
    }
  })
}
