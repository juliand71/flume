/**
 * Creates a chainable mock that mimics the Supabase query builder pattern.
 * Configure per-call results by setting up `supabase.from` mock implementations.
 *
 * Usage:
 *   const chain = createChain({ data: [...], error: null })
 *   supabase.from.mockReturnValue(chain)
 */
export function createChain(result: { data: any; error: any }) {
  const chain: Record<string, any> = {}
  const terminal = () => Promise.resolve(result)

  // Every method returns the chain itself, except `single` which resolves
  const methods = [
    'select',
    'insert',
    'update',
    'upsert',
    'delete',
    'eq',
    'in',
    'single',
  ]

  for (const method of methods) {
    chain[method] = vi.fn().mockReturnValue(chain)
  }

  // `single` is terminal — resolve the promise
  chain.single = vi.fn().mockImplementation(terminal)

  // Make the chain itself thenable so `await supabase.from(...).insert(...)` works
  chain.then = (resolve: any, reject: any) => terminal().then(resolve, reject)

  return chain
}

/**
 * Builds a router: given a map of table name → chain, returns a function
 * suitable for `supabase.from.mockImplementation(...)`.
 */
export function createTableRouter(tables: Record<string, ReturnType<typeof createChain>>) {
  return (table: string) => {
    if (tables[table]) return tables[table]
    // Default: return a chain that resolves to { data: null, error: null }
    return createChain({ data: null, error: null })
  }
}
