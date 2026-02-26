import type { FastifyInstance } from 'fastify'

export async function exchangeRoutes(app: FastifyInstance) {
  // POST /exchange — exchange a Plaid public token for an access token
  app.post('/', async (request, reply) => {
    return reply.status(501).send({ error: 'Not implemented' })
  })
}
