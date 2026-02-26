import type { FastifyInstance } from 'fastify'

export async function syncRoutes(app: FastifyInstance) {
  // POST /sync — trigger a Plaid transactions/sync for a given item
  app.post('/', async (request, reply) => {
    return reply.status(501).send({ error: 'Not implemented' })
  })
}
