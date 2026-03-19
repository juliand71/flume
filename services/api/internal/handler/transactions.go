package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type budgetTransaction struct {
	ID               string  `json:"id"`
	AccountID        string  `json:"account_id"`
	Name             string  `json:"name"`
	Amount           float64 `json:"amount"`
	IsoCurrencyCode  string  `json:"iso_currency_code"`
	Date             string  `json:"date"`
	Pending          bool    `json:"pending"`
	BudgetCategory   string  `json:"budget_category"`
	CategoryOverride *string `json:"category_override"`
}

var validBudgetCategories = map[string]bool{
	"income":   true,
	"fixed":    true,
	"flex":     true,
	"savings":  true,
	"transfer": true,
	"ignore":   true,
}

func ListTransactions(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		periodID := r.URL.Query().Get("period_id")
		if periodID == "" {
			writeError(w, http.StatusBadRequest, "period_id is required")
			return
		}

		// Look up the period and verify ownership
		var startDate, endDate string
		err := pool.QueryRow(r.Context(), `
			SELECT start_date::text, end_date::text
			FROM budget_periods
			WHERE id = $1 AND user_id = $2
		`, periodID, userID).Scan(&startDate, &endDate)
		if err != nil {
			writeError(w, http.StatusNotFound, "budget period not found")
			return
		}

		// Optional category filter
		category := r.URL.Query().Get("category")
		var categoryFilter *string
		if category != "" {
			categoryFilter = &category
		}

		rows, err := pool.Query(r.Context(), `
			SELECT t.id::text, t.account_id::text, t.name, t.amount,
			       t.iso_currency_code, t.date::text, t.pending,
			       t.budget_category, t.category_override
			FROM transactions_with_category t
			WHERE t.user_id = $1
			  AND t.date >= $2::date AND t.date < $3::date
			  AND ($4::text IS NULL OR t.budget_category = $4)
			ORDER BY t.date DESC, t.name
		`, userID, startDate, endDate, categoryFilter)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query transactions")
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

func OverrideTransactionCategory(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		txID := chi.URLParam(r, "id")

		var body struct {
			BudgetCategory string `json:"budget_category"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !validBudgetCategories[body.BudgetCategory] {
			writeError(w, http.StatusBadRequest, "budget_category must be one of: income, fixed, flex, savings, transfer, ignore")
			return
		}

		// Update the override
		tag, err := pool.Exec(r.Context(), `
			UPDATE transactions SET category_override = $3
			WHERE id = $1 AND user_id = $2
		`, txID, userID, body.BudgetCategory)
		if err != nil || tag.RowsAffected() == 0 {
			writeError(w, http.StatusNotFound, "transaction not found")
			return
		}

		// Return the updated transaction with computed budget_category
		var t budgetTransaction
		err = pool.QueryRow(r.Context(), `
			SELECT t.id::text, t.account_id::text, t.name, t.amount,
			       t.iso_currency_code, t.date::text, t.pending,
			       t.budget_category, t.category_override
			FROM transactions_with_category t
			WHERE t.id = $1
		`, txID).Scan(
			&t.ID, &t.AccountID, &t.Name, &t.Amount,
			&t.IsoCurrencyCode, &t.Date, &t.Pending,
			&t.BudgetCategory, &t.CategoryOverride,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch updated transaction")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(t)
	}
}
