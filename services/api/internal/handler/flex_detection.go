package handler

import (
	"encoding/json"
	"math"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type flexDetectionResponse struct {
	TotalFlex        float64 `json:"total_flex"`
	TransactionCount int     `json:"transaction_count"`
}

func DetectFlex(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		startDate := r.URL.Query().Get("start_date")
		endDate := r.URL.Query().Get("end_date")
		if startDate == "" || endDate == "" {
			writeError(w, http.StatusBadRequest, "start_date and end_date are required")
			return
		}

		var totalFlex float64
		var txnCount int
		err := pool.QueryRow(r.Context(), `
			SELECT COALESCE(SUM(amount), 0), COUNT(*)
			FROM transactions_with_category
			WHERE user_id = $1
			  AND budget_category = 'flex'
			  AND amount > 0
			  AND date >= $2::date AND date < $3::date
		`, userID, startDate, endDate).Scan(&totalFlex, &txnCount)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to detect flex spending")
			return
		}

		resp := flexDetectionResponse{
			TotalFlex:        math.Round(totalFlex*100) / 100,
			TransactionCount: txnCount,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
