package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type incomeStream struct {
	ID               string  `json:"id"`
	UserID           string  `json:"user_id"`
	Name             string  `json:"name"`
	EstimatedAmount  float64 `json:"estimated_amount"`
	Frequency        string  `json:"frequency"`
	NextExpectedDate *string `json:"next_expected_date"`
	Active           bool    `json:"active"`
	CreatedAt        string  `json:"created_at"`
}

var validFrequencies = map[string]bool{
	"weekly":      true,
	"biweekly":    true,
	"semimonthly": true,
	"monthly":     true,
}

func ListIncomeStreams(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		rows, err := pool.Query(r.Context(), `
			SELECT id::text, user_id::text, name, estimated_amount, frequency,
			       next_expected_date::text, active, created_at::text
			FROM income_streams
			WHERE user_id = $1 AND active = true
			ORDER BY created_at
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query income streams")
			return
		}
		defer rows.Close()

		streams := []incomeStream{}
		for rows.Next() {
			var s incomeStream
			if err := rows.Scan(
				&s.ID, &s.UserID, &s.Name, &s.EstimatedAmount, &s.Frequency,
				&s.NextExpectedDate, &s.Active, &s.CreatedAt,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan income stream")
				return
			}
			streams = append(streams, s)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"income_streams": streams})
	}
}

func CreateIncomeStream(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			Name             string  `json:"name"`
			EstimatedAmount  float64 `json:"estimated_amount"`
			Frequency        string  `json:"frequency"`
			NextExpectedDate *string `json:"next_expected_date"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.Name == "" {
			writeError(w, http.StatusBadRequest, "name is required")
			return
		}
		if body.EstimatedAmount <= 0 {
			writeError(w, http.StatusBadRequest, "estimated_amount must be positive")
			return
		}
		if !validFrequencies[body.Frequency] {
			writeError(w, http.StatusBadRequest, "frequency must be one of: weekly, biweekly, semimonthly, monthly")
			return
		}

		var s incomeStream
		err := pool.QueryRow(r.Context(), `
			INSERT INTO income_streams (user_id, name, estimated_amount, frequency, next_expected_date)
			VALUES ($1, $2, $3, $4, $5::date)
			RETURNING id::text, user_id::text, name, estimated_amount, frequency,
			          next_expected_date::text, active, created_at::text
		`, userID, body.Name, body.EstimatedAmount, body.Frequency, body.NextExpectedDate,
		).Scan(
			&s.ID, &s.UserID, &s.Name, &s.EstimatedAmount, &s.Frequency,
			&s.NextExpectedDate, &s.Active, &s.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create income stream")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(s)
	}
}

func UpdateIncomeStream(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		id := chi.URLParam(r, "id")

		var body struct {
			Name             *string  `json:"name"`
			EstimatedAmount  *float64 `json:"estimated_amount"`
			Frequency        *string  `json:"frequency"`
			NextExpectedDate *string  `json:"next_expected_date"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.Frequency != nil && !validFrequencies[*body.Frequency] {
			writeError(w, http.StatusBadRequest, "frequency must be one of: weekly, biweekly, semimonthly, monthly")
			return
		}
		if body.EstimatedAmount != nil && *body.EstimatedAmount <= 0 {
			writeError(w, http.StatusBadRequest, "estimated_amount must be positive")
			return
		}

		var s incomeStream
		err := pool.QueryRow(r.Context(), `
			UPDATE income_streams
			SET name = COALESCE($3, name),
			    estimated_amount = COALESCE($4, estimated_amount),
			    frequency = COALESCE($5, frequency),
			    next_expected_date = COALESCE($6::date, next_expected_date)
			WHERE id = $1 AND user_id = $2
			RETURNING id::text, user_id::text, name, estimated_amount, frequency,
			          next_expected_date::text, active, created_at::text
		`, id, userID, body.Name, body.EstimatedAmount, body.Frequency, body.NextExpectedDate,
		).Scan(
			&s.ID, &s.UserID, &s.Name, &s.EstimatedAmount, &s.Frequency,
			&s.NextExpectedDate, &s.Active, &s.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusNotFound, "income stream not found")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(s)
	}
}

func DeleteIncomeStream(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		id := chi.URLParam(r, "id")

		tag, err := pool.Exec(r.Context(), `
			UPDATE income_streams SET active = false
			WHERE id = $1 AND user_id = $2
		`, id, userID)
		if err != nil || tag.RowsAffected() == 0 {
			writeError(w, http.StatusNotFound, "income stream not found")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}
