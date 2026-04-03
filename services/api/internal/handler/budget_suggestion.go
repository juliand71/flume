package handler

import (
	"encoding/json"
	"math"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/juliand71/flume/services/api/internal/auth"
)

func computeSuggestionDates(today time.Time, frequency string, nextExpectedDate *string) (start, end time.Time) {
	switch frequency {
	case "monthly":
		start = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
		end = start.AddDate(0, 1, 0)

	case "biweekly":
		if nextExpectedDate != nil {
			nd, err := time.Parse("2006-01-02", *nextExpectedDate)
			if err == nil {
				start = nd
				for start.After(today) {
					start = start.AddDate(0, 0, -14)
				}
			} else {
				start = today
			}
		} else {
			start = today
		}
		end = start.AddDate(0, 0, 14)

	case "semimonthly":
		if today.Day() <= 15 {
			start = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
			end = time.Date(today.Year(), today.Month(), 16, 0, 0, 0, 0, time.UTC)
		} else {
			start = time.Date(today.Year(), today.Month(), 16, 0, 0, 0, 0, time.UTC)
			end = time.Date(today.Year(), today.Month()+1, 1, 0, 0, 0, 0, time.UTC)
		}

	case "weekly":
		if nextExpectedDate != nil {
			nd, err := time.Parse("2006-01-02", *nextExpectedDate)
			if err == nil {
				start = nd
				for start.After(today) {
					start = start.AddDate(0, 0, -7)
				}
			} else {
				start = today
			}
		} else {
			start = today
		}
		end = start.AddDate(0, 0, 7)

	default:
		start = time.Date(today.Year(), today.Month(), 1, 0, 0, 0, 0, time.UTC)
		end = start.AddDate(0, 1, 0)
	}
	return
}

func computeBudgetSplit(incomeTarget float64) (fixed, flex, savings float64) {
	fixed = math.Round(incomeTarget*0.50*100) / 100
	flex = math.Round(incomeTarget*0.30*100) / 100
	savings = math.Round(incomeTarget*0.20*100) / 100
	return
}

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
		startDate, endDate := computeSuggestionDates(today, frequency, nextExpectedDate)

		incomeTarget := estimatedAmount
		fixedTarget, flexTarget, savingsTarget := computeBudgetSplit(incomeTarget)

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
