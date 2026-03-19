package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type savingsGoal struct {
	ID              string  `json:"id"`
	UserID          string  `json:"user_id"`
	Name            string  `json:"name"`
	TargetAmount    float64 `json:"target_amount"`
	CurrentAmount   float64 `json:"current_amount"`
	Emoji           *string `json:"emoji"`
	IsEmergencyFund bool    `json:"is_emergency_fund"`
	Priority        int     `json:"priority"`
	Archived        bool    `json:"archived"`
	CreatedAt       string  `json:"created_at"`
}

const savingsGoalColumns = `id::text, user_id::text, name, target_amount, current_amount,
	emoji, is_emergency_fund, priority, archived, created_at::text`

func scanSavingsGoal(scan func(dest ...any) error) (savingsGoal, error) {
	var g savingsGoal
	err := scan(&g.ID, &g.UserID, &g.Name, &g.TargetAmount, &g.CurrentAmount,
		&g.Emoji, &g.IsEmergencyFund, &g.Priority, &g.Archived, &g.CreatedAt)
	return g, err
}

func ListSavingsGoals(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		rows, err := pool.Query(r.Context(), `
			SELECT `+savingsGoalColumns+`
			FROM savings_goals
			WHERE user_id = $1 AND archived = false
			ORDER BY priority, created_at
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query savings goals")
			return
		}
		defer rows.Close()

		goals := []savingsGoal{}
		for rows.Next() {
			g, err := scanSavingsGoal(rows.Scan)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan savings goal")
				return
			}
			goals = append(goals, g)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"savings_goals": goals})
	}
}

func CreateSavingsGoal(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			Name            string  `json:"name"`
			TargetAmount    float64 `json:"target_amount"`
			Emoji           *string `json:"emoji"`
			IsEmergencyFund bool    `json:"is_emergency_fund"`
			Priority        *int    `json:"priority"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.Name == "" {
			writeError(w, http.StatusBadRequest, "name is required")
			return
		}
		if body.TargetAmount <= 0 {
			writeError(w, http.StatusBadRequest, "target_amount must be positive")
			return
		}

		priority := 0
		if body.Priority != nil {
			priority = *body.Priority
		}

		g, err := scanSavingsGoal(pool.QueryRow(r.Context(), `
			INSERT INTO savings_goals (user_id, name, target_amount, emoji, is_emergency_fund, priority)
			VALUES ($1, $2, $3, $4, $5, $6)
			RETURNING `+savingsGoalColumns+`
		`, userID, body.Name, body.TargetAmount, body.Emoji, body.IsEmergencyFund, priority).Scan)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create savings goal")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(g)
	}
}

func UpdateSavingsGoal(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		id := chi.URLParam(r, "id")

		var body struct {
			Name            *string  `json:"name"`
			TargetAmount    *float64 `json:"target_amount"`
			Emoji           *string  `json:"emoji"`
			IsEmergencyFund *bool    `json:"is_emergency_fund"`
			Priority        *int     `json:"priority"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.TargetAmount != nil && *body.TargetAmount <= 0 {
			writeError(w, http.StatusBadRequest, "target_amount must be positive")
			return
		}

		g, err := scanSavingsGoal(pool.QueryRow(r.Context(), `
			UPDATE savings_goals
			SET name = COALESCE($3, name),
			    target_amount = COALESCE($4, target_amount),
			    emoji = COALESCE($5, emoji),
			    is_emergency_fund = COALESCE($6, is_emergency_fund),
			    priority = COALESCE($7, priority)
			WHERE id = $1 AND user_id = $2
			RETURNING `+savingsGoalColumns+`
		`, id, userID, body.Name, body.TargetAmount, body.Emoji, body.IsEmergencyFund, body.Priority).Scan)
		if err != nil {
			writeError(w, http.StatusNotFound, "savings goal not found")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(g)
	}
}

func DeleteSavingsGoal(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		id := chi.URLParam(r, "id")

		tag, err := pool.Exec(r.Context(), `
			UPDATE savings_goals SET archived = true
			WHERE id = $1 AND user_id = $2
		`, id, userID)
		if err != nil || tag.RowsAffected() == 0 {
			writeError(w, http.StatusNotFound, "savings goal not found")
			return
		}

		w.WriteHeader(http.StatusNoContent)
	}
}

func FillSavingsGoals(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			Allocations []struct {
				SavingsGoalID string  `json:"savings_goal_id"`
				Amount        float64 `json:"amount"`
			} `json:"allocations"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if len(body.Allocations) == 0 {
			writeError(w, http.StatusBadRequest, "allocations is required")
			return
		}
		for _, a := range body.Allocations {
			if a.SavingsGoalID == "" {
				writeError(w, http.StatusBadRequest, "savings_goal_id is required for each allocation")
				return
			}
			if a.Amount <= 0 {
				writeError(w, http.StatusBadRequest, "amount must be positive for each allocation")
				return
			}
		}

		tx, err := pool.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to begin transaction")
			return
		}
		defer tx.Rollback(r.Context())

		for _, a := range body.Allocations {
			tag, err := tx.Exec(r.Context(), `
				UPDATE savings_goals
				SET current_amount = current_amount + $3
				WHERE id = $1 AND user_id = $2 AND archived = false
			`, a.SavingsGoalID, userID, a.Amount)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to update savings goal")
				return
			}
			if tag.RowsAffected() == 0 {
				writeError(w, http.StatusNotFound, "savings goal not found: "+a.SavingsGoalID)
				return
			}
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to commit transaction")
			return
		}

		// Return updated goals list
		rows, err := pool.Query(r.Context(), `
			SELECT `+savingsGoalColumns+`
			FROM savings_goals
			WHERE user_id = $1 AND archived = false
			ORDER BY priority, created_at
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query savings goals")
			return
		}
		defer rows.Close()

		goals := []savingsGoal{}
		for rows.Next() {
			g, err := scanSavingsGoal(rows.Scan)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan savings goal")
				return
			}
			goals = append(goals, g)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"savings_goals": goals})
	}
}
