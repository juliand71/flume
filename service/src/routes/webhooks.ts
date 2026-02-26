import type { FastifyInstance } from 'fastify'

export async function webhookRoutes(app: FastifyInstance) {
  // POST /webhooks — receive Plaid webhook events
  app.post('/', async (request, reply) => {
    return reply.status(501).send({ error: 'Not implemented' })
  })
}
