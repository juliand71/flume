package handler

import (
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type categoryMapping struct {
	ID                    string  `json:"id"`
	UserID                *string `json:"user_id"`
	PlaidPrimaryCategory  string  `json:"plaid_primary_category"`
	PlaidDetailedCategory *string `json:"plaid_detailed_category"`
	BudgetCategory        string  `json:"budget_category"`
	CreatedAt             string  `json:"created_at"`
}

func ListCategoryMappings(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		rows, err := pool.Query(r.Context(), `
			SELECT id::text, user_id::text, plaid_primary_category,
			       plaid_detailed_category, budget_category, created_at::text
			FROM category_mappings
			WHERE user_id IS NULL OR user_id = $1
			ORDER BY plaid_primary_category, plaid_detailed_category
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query category mappings")
			return
		}
		defer rows.Close()

		mappings := []categoryMapping{}
		for rows.Next() {
			var m categoryMapping
			if err := rows.Scan(
				&m.ID, &m.UserID, &m.PlaidPrimaryCategory,
				&m.PlaidDetailedCategory, &m.BudgetCategory, &m.CreatedAt,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan category mapping")
				return
			}
			mappings = append(mappings, m)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"category_mappings": mappings})
	}
}

func CreateCategoryMapping(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			PlaidPrimaryCategory  string  `json:"plaid_primary_category"`
			PlaidDetailedCategory *string `json:"plaid_detailed_category"`
			BudgetCategory        string  `json:"budget_category"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.PlaidPrimaryCategory == "" {
			writeError(w, http.StatusBadRequest, "plaid_primary_category is required")
			return
		}
		if !validBudgetCategories[body.BudgetCategory] {
			writeError(w, http.StatusBadRequest, "budget_category must be one of: income, fixed, flex, savings, transfer, ignore")
			return
		}

		var m categoryMapping
		err := pool.QueryRow(r.Context(), `
			INSERT INTO category_mappings (user_id, plaid_primary_category, plaid_detailed_category, budget_category)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT ON CONSTRAINT category_mappings_unique
			DO UPDATE SET budget_category = EXCLUDED.budget_category
			RETURNING id::text, user_id::text, plaid_primary_category,
			          plaid_detailed_category, budget_category, created_at::text
		`, userID, body.PlaidPrimaryCategory, body.PlaidDetailedCategory, body.BudgetCategory,
		).Scan(
			&m.ID, &m.UserID, &m.PlaidPrimaryCategory,
			&m.PlaidDetailedCategory, &m.BudgetCategory, &m.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to create category mapping")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		json.NewEncoder(w).Encode(m)
	}
}
