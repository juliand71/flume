package handler

import (
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type categoryEntry struct {
	Category string  `json:"category"`
	Target   float64 `json:"target"`
	Actual   float64 `json:"actual"`
}

type categorySummaryResponse struct {
	PeriodID   string          `json:"period_id"`
	StartDate  string          `json:"start_date"`
	EndDate    string          `json:"end_date"`
	Categories []categoryEntry `json:"categories"`
	Surplus    float64         `json:"surplus"`
}

func GetCategorySummary(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		p, err := currentPeriodForUser(r.Context(), pool, userID)
		if err != nil {
			writeError(w, http.StatusNotFound, "no active budget period")
			return
		}

		// Get actuals grouped by budget_category
		rows, err := pool.Query(r.Context(), `
			SELECT budget_category, coalesce(sum(amount), 0) as total
			FROM transactions_with_category
			WHERE user_id = $1 AND date >= $2::date AND date < $3::date
			GROUP BY budget_category
		`, userID, p.StartDate, p.EndDate)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to compute category summary")
			return
		}
		defer rows.Close()

		actuals := map[string]float64{}
		for rows.Next() {
			var category string
			var total float64
			if err := rows.Scan(&category, &total); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan category row")
				return
			}
			actuals[category] = total
		}

		categories := []categoryEntry{
			{Category: "income", Target: p.IncomeTarget, Actual: actuals["income"]},
			{Category: "fixed", Target: p.FixedTarget, Actual: actuals["fixed"]},
			{Category: "flex", Target: p.FlexTarget, Actual: actuals["flex"]},
			{Category: "savings", Target: p.SavingsTarget, Actual: actuals["savings"]},
		}

		surplus := actuals["income"] - actuals["fixed"] - actuals["flex"]

		resp := categorySummaryResponse{
			PeriodID:   p.ID,
			StartDate:  p.StartDate,
			EndDate:    p.EndDate,
			Categories: categories,
			Surplus:    surplus,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}
