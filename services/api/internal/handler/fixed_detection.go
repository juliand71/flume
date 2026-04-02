package handler

import (
	"encoding/json"
	"math"
	"net/http"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/juliand71/flume/services/api/internal/auth"
)

type detectedFixedExpense struct {
	Name          string              `json:"name"`
	TotalAmount   float64             `json:"total_amount"`
	Occurrences   int                 `json:"occurrences"`
	PlaidCategory string              `json:"plaid_category"`
	Transactions  []streamTransaction `json:"transactions"`
}

type fixedDetectionResponse struct {
	DetectedExpenses []detectedFixedExpense `json:"detected_expenses"`
	TotalFixed       float64               `json:"total_fixed"`
}

func DetectFixed(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		startDate := r.URL.Query().Get("start_date")
		endDate := r.URL.Query().Get("end_date")
		if startDate == "" || endDate == "" {
			writeError(w, http.StatusBadRequest, "start_date and end_date are required")
			return
		}

		rows, err := pool.Query(r.Context(), `
			SELECT name, amount, date::text,
				COALESCE(personal_finance_category->>'primary', '') as plaid_category
			FROM transactions_with_category
			WHERE user_id = $1
			  AND budget_category = 'fixed'
			  AND amount > 0
			  AND date >= $2::date AND date < $3::date
			ORDER BY name, date
		`, userID, startDate, endDate)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to detect fixed expenses")
			return
		}
		defer rows.Close()

		type txn struct {
			name          string
			amount        float64
			date          string
			plaidCategory string
		}

		groups := map[string][]txn{}
		for rows.Next() {
			var t txn
			if err := rows.Scan(&t.name, &t.amount, &t.date, &t.plaidCategory); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan transaction")
				return
			}
			key := normalizeTxnName(t.name)
			groups[key] = append(groups[key], t)
		}

		var expenses []detectedFixedExpense
		var grandTotal float64

		for _, txns := range groups {
			var total float64
			var streamTxns []streamTransaction
			for _, t := range txns {
				total += t.amount
				streamTxns = append(streamTxns, streamTransaction{
					Date:   t.date,
					Amount: math.Round(t.amount*100) / 100,
					Name:   t.name,
				})
			}

			total = math.Round(total*100) / 100
			grandTotal += total

			displayName := txns[len(txns)-1].name
			plaidCategory := txns[0].plaidCategory

			expenses = append(expenses, detectedFixedExpense{
				Name:          displayName,
				TotalAmount:   total,
				Occurrences:   len(txns),
				PlaidCategory: plaidCategory,
				Transactions:  streamTxns,
			})
		}

		sort.Slice(expenses, func(i, j int) bool {
			return expenses[i].TotalAmount > expenses[j].TotalAmount
		})

		resp := fixedDetectionResponse{
			DetectedExpenses: expenses,
			TotalFixed:       math.Round(grandTotal*100) / 100,
		}
		if resp.DetectedExpenses == nil {
			resp.DetectedExpenses = []detectedFixedExpense{}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
