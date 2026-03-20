package handler

import (
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

func GetSyncStatus(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var result struct {
			HasPlaidItems    bool `json:"has_plaid_items"`
			TransactionCount int  `json:"transaction_count"`
		}

		err := pool.QueryRow(r.Context(), `
			SELECT
				EXISTS(SELECT 1 FROM plaid_items WHERE user_id = $1) as has_plaid_items,
				(SELECT count(*) FROM transactions WHERE user_id = $1)::int as transaction_count
		`, userID).Scan(&result.HasPlaidItems, &result.TransactionCount)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch sync status")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}
