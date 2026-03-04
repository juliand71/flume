import type { FastifyInstance } from 'fastify'
import { CountryCode, Products } from 'plaid'
import { authenticateUser } from '../lib/auth.js'
import { plaid } from '../lib/plaid.js'

export async function linkRoutes(app: FastifyInstance) {
  // POST /link/token — generate a Plaid Link token for the client
  app.post('/token', async (request, reply) => {
    try {
      const userId = await authenticateUser(request)

      const webhookUrl = process.env.RAILWAY_PUBLIC_DOMAIN
        ? `https://${process.env.RAILWAY_PUBLIC_DOMAIN}/webhooks`
        : undefined

      const response = await plaid.linkTokenCreate({
        user: { client_user_id: userId },
        client_name: 'Flume',
        products: [Products.Transactions],
        country_codes: [CountryCode.Us],
        language: 'en',
        ...(webhookUrl ? { webhook: webhookUrl } : {}),
      })

      return { link_token: response.data.link_token }
    } catch (err: any) {
      const status = err.statusCode ?? 500
      request.log.error(err)
      return reply.status(status).send({ error: err.message ?? 'Internal server error' })
    }
  })
}
