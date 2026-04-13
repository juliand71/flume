package handler

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/juliand71/flume/services/api/internal/auth"
)

type debugTransactionInput struct {
	Name                    string          `json:"name"`
	Amount                  float64         `json:"amount"`
	Date                    string          `json:"date"`
	PersonalFinanceCategory json.RawMessage `json:"personal_finance_category"`
	AccountID               string          `json:"account_id"`
}

type debugTransactionBatch struct {
	Transactions []debugTransactionInput `json:"transactions"`
}

func randomID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return fmt.Sprintf("%x", b)
}

// CreateDebugTransaction handles POST /debug/transactions.
// Accepts a single transaction or {"transactions": [...]}.
func CreateDebugTransaction(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		// Parse body — try batch first, fall back to single
		var inputs []debugTransactionInput

		var raw json.RawMessage
		if err := json.NewDecoder(r.Body).Decode(&raw); err != nil {
			writeError(w, http.StatusBadRequest, "invalid JSON body")
			return
		}

		var batch debugTransactionBatch
		if err := json.Unmarshal(raw, &batch); err == nil && len(batch.Transactions) > 0 {
			inputs = batch.Transactions
		} else {
			var single debugTransactionInput
			if err := json.Unmarshal(raw, &single); err != nil {
				writeError(w, http.StatusBadRequest, "expected a transaction object or {\"transactions\": [...]}")
				return
			}
			inputs = []debugTransactionInput{single}
		}

		if len(inputs) == 0 {
			writeError(w, http.StatusBadRequest, "no transactions provided")
			return
		}

		// Resolve default account (user's checking) if needed
		var defaultAccountID string
		for _, t := range inputs {
			if t.AccountID == "" {
				// Look up checking account once
				err := pool.QueryRow(r.Context(), `
					SELECT a.id::text FROM accounts a
					JOIN account_roles ar ON ar.account_id = a.id
					WHERE ar.user_id = $1 AND ar.account_role = 'checking'
					LIMIT 1
				`, userID).Scan(&defaultAccountID)
				if err != nil {
					writeError(w, http.StatusBadRequest, "no checking account found for user — specify account_id explicitly")
					return
				}
				break
			}
		}

		today := time.Now().Format("2006-01-02")
		defaultCategory := json.RawMessage(`{"primary":"GENERAL_MERCHANDISE","detailed":"GENERAL_MERCHANDISE_OTHER"}`)

		var createdIDs []string
		for _, t := range inputs {
			if t.Name == "" {
				writeError(w, http.StatusBadRequest, "name is required for each transaction")
				return
			}

			accountID := t.AccountID
			if accountID == "" {
				accountID = defaultAccountID
			}

			date := t.Date
			if date == "" {
				date = today
			}

			pfc := t.PersonalFinanceCategory
			if len(pfc) == 0 || string(pfc) == "null" {
				pfc = defaultCategory
			}

			plaidTxnID := "debug_txn_" + randomID()

			var id string
			err := pool.QueryRow(r.Context(), `
				INSERT INTO transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category)
				VALUES ($1::uuid, $2::uuid, $3, $4, $5, $6::date, $7::jsonb)
				RETURNING id::text
			`, accountID, userID, plaidTxnID, t.Name, t.Amount, date, string(pfc)).Scan(&id)
			if err != nil {
				writeError(w, http.StatusInternalServerError, fmt.Sprintf("failed to insert transaction: %v", err))
				return
			}
			createdIDs = append(createdIDs, id)
		}

		// Fetch created transactions from the view so budget_category is computed
		rows, err := pool.Query(r.Context(), `
			SELECT t.id::text, t.account_id::text, t.name, t.amount,
			       t.iso_currency_code, t.date::text, t.pending,
			       t.budget_category, t.category_override
			FROM transactions_with_category t
			WHERE t.id = ANY($1::uuid[])
			ORDER BY t.date DESC, t.name
		`, createdIDs)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch created transactions")
			return
		}
		defer rows.Close()

		transactions := []budgetTransaction{}
		for rows.Next() {
			var t budgetTransaction
			if err := rows.Scan(
				&t.ID, &t.AccountID, &t.Name, &t.Amount,
				&t.IsoCurrencyCode, &t.Date, &t.Pending,
				&t.BudgetCategory, &t.CategoryOverride,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan transaction")
				return
			}
			transactions = append(transactions, t)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"transactions": transactions})
	}
}

// DeleteDebugTransactions handles DELETE /debug/transactions.
// Deletes all transactions with plaid_transaction_id LIKE 'debug_txn_%' for the authed user.
func DeleteDebugTransactions(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		tag, err := pool.Exec(r.Context(), `
			DELETE FROM transactions
			WHERE user_id = $1 AND plaid_transaction_id LIKE 'debug_txn_%'
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to delete debug transactions")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"deleted": tag.RowsAffected(),
		})
	}
}
