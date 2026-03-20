package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type budgetPeriod struct {
	ID             string  `json:"id"`
	UserID         string  `json:"user_id"`
	StartDate      string  `json:"start_date"`
	EndDate        string  `json:"end_date"`
	IncomeTarget   float64 `json:"income_target"`
	FixedTarget    float64 `json:"fixed_target"`
	FlexTarget     float64 `json:"flex_target"`
	SavingsTarget  float64 `json:"savings_target"`
	IncomeStreamID *string `json:"income_stream_id"`
	CreatedAt      string  `json:"created_at"`
}

type budgetPeriodWithActuals struct {
	ID             string  `json:"id"`
	UserID         string  `json:"user_id"`
	StartDate      string  `json:"start_date"`
	EndDate        string  `json:"end_date"`
	IncomeTarget   float64 `json:"income_target"`
	FixedTarget    float64 `json:"fixed_target"`
	FlexTarget     float64 `json:"flex_target"`
	SavingsTarget  float64 `json:"savings_target"`
	IncomeStreamID *string `json:"income_stream_id"`
	CreatedAt      string  `json:"created_at"`
	ActualIncome   float64 `json:"actual_income"`
	ActualFixed    float64 `json:"actual_fixed"`
	ActualFlex     float64 `json:"actual_flex"`
	ActualSavings  float64 `json:"actual_savings"`
	Surplus        float64 `json:"surplus"`
}

// currentPeriodForUser returns the budget period covering today for the given user.
func currentPeriodForUser(ctx context.Context, pool *pgxpool.Pool, userID string) (*budgetPeriod, error) {
	var p budgetPeriod
	err := pool.QueryRow(ctx, `
		SELECT id::text, user_id::text, start_date::text, end_date::text,
		       income_target, fixed_target, flex_target, savings_target,
		       income_stream_id::text, created_at::text
		FROM budget_periods
		WHERE user_id = $1 AND start_date <= CURRENT_DATE AND end_date > CURRENT_DATE
		ORDER BY start_date DESC
		LIMIT 1
	`, userID).Scan(
		&p.ID, &p.UserID, &p.StartDate, &p.EndDate,
		&p.IncomeTarget, &p.FixedTarget, &p.FlexTarget, &p.SavingsTarget,
		&p.IncomeStreamID, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func GetCurrentPeriod(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		p, err := currentPeriodForUser(r.Context(), pool, userID)
		if err != nil {
			writeError(w, http.StatusNotFound, "no active budget period")
			return
		}

		// Compute actuals from transactions_with_category
		var actualIncome, actualFixed, actualFlex, actualSavings float64
		err = pool.QueryRow(r.Context(), `
			SELECT
				coalesce(sum(amount) FILTER (WHERE budget_category = 'income'), 0),
				coalesce(sum(amount) FILTER (WHERE budget_category = 'fixed'), 0),
				coalesce(sum(amount) FILTER (WHERE budget_category = 'flex'), 0),
				coalesce(sum(amount) FILTER (WHERE budget_category = 'savings'), 0)
			FROM transactions_with_category
			WHERE user_id = $1 AND date >= $2::date AND date < $3::date
		`, userID, p.StartDate, p.EndDate).Scan(
			&actualIncome, &actualFixed, &actualFlex, &actualSavings,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to compute actuals")
			return
		}

		result := budgetPeriodWithActuals{
			ID:             p.ID,
			UserID:         p.UserID,
			StartDate:      p.StartDate,
			EndDate:        p.EndDate,
			IncomeTarget:   p.IncomeTarget,
			FixedTarget:    p.FixedTarget,
			FlexTarget:     p.FlexTarget,
			SavingsTarget:  p.SavingsTarget,
			IncomeStreamID: p.IncomeStreamID,
			CreatedAt:      p.CreatedAt,
			ActualIncome:   actualIncome,
			ActualFixed:    actualFixed,
			ActualFlex:     actualFlex,
			ActualSavings:  actualSavings,
			Surplus:        -actualIncome - actualFixed - actualFlex,
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(result)
	}
}

func ListPeriods(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		limit := 20
		offset := 0
		if v := r.URL.Query().Get("limit"); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 100 {
				limit = n
			}
		}
		if v := r.URL.Query().Get("offset"); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n >= 0 {
				offset = n
			}
		}

		rows, err := pool.Query(r.Context(), `
			SELECT id::text, user_id::text, start_date::text, end_date::text,
			       income_target, fixed_target, flex_target, savings_target,
			       income_stream_id::text, created_at::text
			FROM budget_periods
			WHERE user_id = $1
			ORDER BY start_date DESC
			LIMIT $2 OFFSET $3
		`, userID, limit, offset)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query budget periods")
			return
		}
		defer rows.Close()

		periods := []budgetPeriod{}
		for rows.Next() {
			var p budgetPeriod
			if err := rows.Scan(
				&p.ID, &p.UserID, &p.StartDate, &p.EndDate,
				&p.IncomeTarget, &p.FixedTarget, &p.FlexTarget, &p.SavingsTarget,
				&p.IncomeStreamID, &p.CreatedAt,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan budget period")
				return
			}
			periods = append(periods, p)
		}

		// Get total count
		var total int
		pool.QueryRow(r.Context(), `
			SELECT count(*) FROM budget_periods WHERE user_id = $1
		`, userID).Scan(&total)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"periods": periods,
			"total":   total,
		})
	}
}

func CreatePeriod(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			StartDate      string  `json:"start_date"`
			EndDate        string  `json:"end_date"`
			IncomeTarget   float64 `json:"income_target"`
			FixedTarget    float64 `json:"fixed_target"`
			FlexTarget     float64 `json:"flex_target"`
			SavingsTarget  float64 `json:"savings_target"`
			IncomeStreamID *string `json:"income_stream_id"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.StartDate == "" || body.EndDate == "" {
			writeError(w, http.StatusBadRequest, "start_date and end_date are required")
			return
		}
		if body.EndDate <= body.StartDate {
			writeError(w, http.StatusBadRequest, "end_date must be after start_date")
			return
		}

		var p budgetPeriod
		err := pool.QueryRow(r.Context(), `
			INSERT INTO budget_periods (user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target, income_stream_id)
			VALUES ($1, $2::date, $3::date, $4, $5, $6, $7, $8::uuid)
			RETURNING id::text, user_id::text, start_date::text, end_date::text,
			          income_target, fixed_target, flex_target, savings_target,
			          income_stream_id::text, created_at::text
		`, userID, body.StartDate, body.EndDate, body.IncomeTarget, body.FixedTarget,
			body.FlexTarget, body.SavingsTarget, body.IncomeStreamID,
		).Scan(
			&p.ID, &p.UserID, &p.StartDate, &p.EndDate,
			&p.IncomeTarget, &p.FixedTarget, &p.FlexTarget, &p.SavingsTarget,
			&p.IncomeStreamID, &p.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create budget period")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(p)
	}
}

func UpdatePeriod(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		id := chi.URLParam(r, "id")

		var body struct {
			IncomeTarget  *float64 `json:"income_target"`
			FixedTarget   *float64 `json:"fixed_target"`
			FlexTarget    *float64 `json:"flex_target"`
			SavingsTarget *float64 `json:"savings_target"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		var p budgetPeriod
		err := pool.QueryRow(r.Context(), `
			UPDATE budget_periods
			SET income_target = COALESCE($3, income_target),
			    fixed_target = COALESCE($4, fixed_target),
			    flex_target = COALESCE($5, flex_target),
			    savings_target = COALESCE($6, savings_target)
			WHERE id = $1 AND user_id = $2
			RETURNING id::text, user_id::text, start_date::text, end_date::text,
			          income_target, fixed_target, flex_target, savings_target,
			          income_stream_id::text, created_at::text
		`, id, userID, body.IncomeTarget, body.FixedTarget, body.FlexTarget, body.SavingsTarget,
		).Scan(
			&p.ID, &p.UserID, &p.StartDate, &p.EndDate,
			&p.IncomeTarget, &p.FixedTarget, &p.FlexTarget, &p.SavingsTarget,
			&p.IncomeStreamID, &p.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusNotFound, "budget period not found")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(p)
	}
}
