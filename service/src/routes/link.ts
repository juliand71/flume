import type { FastifyInstance } from 'fastify'

export async function linkRoutes(app: FastifyInstance) {
  // POST /link/token — generate a Plaid Link token for the client
  app.post('/token', async (request, reply) => {
    return reply.status(501).send({ error: 'Not implemented' })
  })
}
