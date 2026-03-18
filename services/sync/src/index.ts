import Fastify from 'fastify'
import { linkRoutes } from './routes/link.js'
import { exchangeRoutes } from './routes/exchange.js'
import { syncRoutes } from './routes/sync.js'
import { webhookRoutes } from './routes/webhooks.js'

const required = ['SUPABASE_URL', 'SUPABASE_SECRET_KEY', 'PLAID_CLIENT_ID', 'PLAID_SECRET']
for (const key of required) {
  if (!process.env[key]) throw new Error(`Missing required env var: ${key}`)
}

const app = Fastify({ logger: true })

app.register(linkRoutes, { prefix: '/link' })
app.register(exchangeRoutes, { prefix: '/exchange' })
app.register(syncRoutes, { prefix: '/sync' })
app.register(webhookRoutes, { prefix: '/webhooks' })

await app.listen({ port: 3000, host: '0.0.0.0' })
process.on('SIGTERM', () => app.close())
