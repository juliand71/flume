package handler

import (
	"encoding/json"
	"math"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type budgetSuggestion struct {
	StartDate    string  `json:"start_date"`
	EndDate      string  `json:"end_date"`
	IncomeTarget float64 `json:"income_target"`
	FixedTarget  float64 `json:"fixed_target"`
	FlexTarget   float64 `json:"flex_target"`
	SavingsTarget float64 `json:"savings_target"`
}

func SuggestPeriod(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			IncomeStreamID string `json:"income_stream_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.IncomeStreamID == "" {
			writeError(w, http.StatusBadRequest, "income_stream_id is required")
			return
		}

		// Fetch the income stream
		var frequency string
		var estimatedAmount float64
		var nextExpectedDate *string
		err := pool.QueryRow(r.Context(), `
			SELECT frequency, estimated_amount, next_expected_date::text
			FROM income_streams
			WHERE id = $1 AND user_id = $2 AND active = true
		`, body.IncomeStreamID, userID).Scan(&frequency, &estimatedAmount, &nextExpectedDate)
		if err != nil {
			writeError(w, http.StatusNotFound, "income stream not found")
			return
		}

		today := time.Now().UTC().Truncate(24 * time.Hour)
		var startDate, endDate time.Time

		switch frequency {
		case "monthly":
			startDate = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
			endDate = startDate.AddDate(0, 1, 0)

		case "biweekly":
			if nextExpectedDate != nil {
				nd, err := time.Parse("2006-01-02", *nextExpectedDate)
				if err == nil {
					// Find the most recent pay date on or before today
					startDate = nd
					for startDate.After(today) {
						startDate = startDate.AddDate(0, 0, -14)
					}
				} else {
					startDate = today
				}
			} else {
				startDate = today
			}
			endDate = startDate.AddDate(0, 0, 14)

		case "semimonthly":
			if today.Day() <= 15 {
				startDate = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
				endDate = time.Date(today.Year(), today.Month(), 16, 0, 0, 0, 0, time.UTC)
			} else {
				startDate = time.Date(today.Year(), today.Month(), 16, 0, 0, 0, 0, time.UTC)
				endDate = time.Date(today.Year(), today.Month()+1, 1, 0, 0, 0, 0, time.UTC)
			}

		case "weekly":
			if nextExpectedDate != nil {
				nd, err := time.Parse("2006-01-02", *nextExpectedDate)
				if err == nil {
					startDate = nd
					for startDate.After(today) {
						startDate = startDate.AddDate(0, 0, -7)
					}
				} else {
					startDate = today
				}
			} else {
				startDate = today
			}
			endDate = startDate.AddDate(0, 0, 7)

		default:
			// Fallback to monthly
			startDate = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
			endDate = startDate.AddDate(0, 1, 0)
		}

		// 50/30/20 split
		incomeTarget := estimatedAmount
		fixedTarget := math.Round(incomeTarget*0.50*100) / 100
		flexTarget := math.Round(incomeTarget*0.30*100) / 100
		savingsTarget := math.Round(incomeTarget*0.20*100) / 100

		suggestion := budgetSuggestion{
			StartDate:     startDate.Format("2006-01-02"),
			EndDate:       endDate.Format("2006-01-02"),
			IncomeTarget:  incomeTarget,
			FixedTarget:   fixedTarget,
			FlexTarget:    flexTarget,
			SavingsTarget: savingsTarget,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(suggestion)
	}
}
