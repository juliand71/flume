import Fastify from 'fastify'
import { linkRoutes } from './routes/link.js'
import { exchangeRoutes } from './routes/exchange.js'
import { syncRoutes } from './routes/sync.js'
import { webhookRoutes } from './routes/webhooks.js'

const app = Fastify({ logger: true })

app.register(linkRoutes, { prefix: '/link' })
app.register(exchangeRoutes, { prefix: '/exchange' })
app.register(syncRoutes, { prefix: '/sync' })
app.register(webhookRoutes, { prefix: '/webhooks' })

app.listen({ port: 3000, host: '0.0.0.0' })
