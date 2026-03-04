import type { FastifyInstance } from 'fastify'
import { supabase } from '../lib/supabase.js'
import { syncTransactions } from '../lib/sync.js'
import { verifyPlaidWebhook } from '../lib/webhook-verify.js'

interface WebhookBody {
  webhook_type: string
  webhook_code: string
  item_id: string
}

const TRANSACTION_CODES = new Set([
  'SYNC_UPDATES_AVAILABLE',
  'DEFAULT_UPDATE',
  'INITIAL_UPDATE',
  'HISTORICAL_UPDATE',
])

export async function webhookRoutes(app: FastifyInstance) {
  // POST /webhooks — receive Plaid webhook events
  app.post('/', async (request, reply) => {
    try {
      // Verify webhook signature
      const verificationHeader = request.headers['plaid-verification'] as string | undefined
      if (!verificationHeader) {
        return reply.status(401).send({ error: 'Missing Plaid-Verification header' })
      }

      const rawBody = JSON.stringify(request.body)
      await verifyPlaidWebhook(rawBody, verificationHeader)

      const body = request.body as WebhookBody
      request.log.info({ webhook_type: body.webhook_type, webhook_code: body.webhook_code }, 'Received Plaid webhook')

      // Handle transaction-related webhooks
      if (body.webhook_type === 'TRANSACTIONS' && TRANSACTION_CODES.has(body.webhook_code)) {
        // Look up our internal plaid item by Plaid's item_id
        const { data: item, error } = await supabase
          .from('plaid_items')
          .select('id')
          .eq('plaid_item_id', body.item_id)
          .single()

        if (error || !item) {
          request.log.warn({ plaid_item_id: body.item_id }, 'Webhook received for unknown item')
          return { success: true }
        }

        await syncTransactions(item.id)
      }

      return { success: true }
    } catch (err: any) {
      const status = err.statusCode ?? 500
      request.log.error(err)
      return reply.status(status).send({ error: err.message ?? 'Internal server error' })
    }
  })
}
