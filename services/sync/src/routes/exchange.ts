import type { FastifyInstance } from 'fastify'
import { authenticateUser } from '../lib/auth.js'
import { plaid } from '../lib/plaid.js'
import { supabase } from '../lib/supabase.js'
import { syncTransactions } from '../lib/sync.js'

interface ExchangeBody {
  public_token: string
  institution: {
    name: string
    institution_id: string
  }
}

function resolveAccountRole(
  type: string,
  subtype: string | null
): 'checking' | 'savings' | 'credit_card' | null {
  if (type === 'depository' && subtype === 'checking') return 'checking'
  if (type === 'depository' && subtype === 'savings') return 'savings'
  if (type === 'credit') return 'credit_card'
  return null
}

export async function exchangeRoutes(app: FastifyInstance) {
  // POST /exchange — exchange a Plaid public token for an access token
  app.post('/', async (request, reply) => {
    try {
      const userId = await authenticateUser(request)
      const body = request.body as ExchangeBody

      if (!body?.public_token || !body?.institution?.name) {
        return reply.status(400).send({ error: 'Missing public_token or institution' })
      }

      // Exchange public token for access token
      const exchangeResponse = await plaid.itemPublicTokenExchange({
        public_token: body.public_token,
      })

      const { access_token, item_id } = exchangeResponse.data

      // Insert plaid item
      const { data: plaidItem, error: insertError } = await supabase
        .from('plaid_items')
        .insert({
          user_id: userId,
          plaid_item_id: item_id,
          access_token,
          institution_name: body.institution.name,
        })
        .select('id')
        .single()

      if (insertError) {
        throw { statusCode: 500, message: `Failed to store plaid item: ${insertError.message}` }
      }

      // Fetch accounts from Plaid and insert them
      const accountsResponse = await plaid.accountsGet({ access_token })

      const accountRows = accountsResponse.data.accounts.map((account) => ({
        plaid_item_id: plaidItem.id,
        user_id: userId,
        plaid_account_id: account.account_id,
        name: account.name,
        official_name: account.official_name,
        type: account.type,
        subtype: account.subtype,
        mask: account.mask,
        current_balance: account.balances.current,
        available_balance: account.balances.available,
        iso_currency_code: account.balances.iso_currency_code ?? 'USD',
      }))

      const { data: upsertedAccounts, error: accountsError } = await supabase
        .from('accounts')
        .upsert(accountRows, { onConflict: 'plaid_account_id' })
        .select('id, type, subtype')

      if (accountsError) {
        throw { statusCode: 500, message: `Failed to store accounts: ${accountsError.message}` }
      }

      // Assign account roles based on Plaid type/subtype
      const roleRows = (upsertedAccounts ?? [])
        .map((a: { id: string; type: string; subtype: string | null }) => ({
          account_id: a.id,
          user_id: userId,
          role: resolveAccountRole(a.type, a.subtype),
        }))
        .filter((r): r is { account_id: string; user_id: string; role: 'checking' | 'savings' | 'credit_card' } => r.role !== null)
        .map(({ account_id, user_id, role }) => ({ account_id, user_id, account_role: role }))

      if (roleRows.length > 0) {
        const { error: rolesError } = await supabase
          .from('account_roles')
          .upsert(roleRows, { onConflict: 'account_id' })

        if (rolesError) {
          throw { statusCode: 500, message: `Failed to store account roles: ${rolesError.message}` }
        }
      }

      // Sync transactions immediately so users see data right away
      await syncTransactions(plaidItem.id)

      return { success: true, plaid_item_id: plaidItem.id }
    } catch (err: any) {
      const status = err.statusCode ?? 500
      request.log.error(err)
      return reply.status(status).send({ error: err.message ?? 'Internal server error' })
    }
  })
}
