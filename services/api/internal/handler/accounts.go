package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

type accountWithRole struct {
	ID               string   `json:"id"`
	PlaidItemID      string   `json:"plaid_item_id"`
	UserID           string   `json:"user_id"`
	PlaidAccountID   string   `json:"plaid_account_id"`
	Name             string   `json:"name"`
	OfficialName     *string  `json:"official_name"`
	Type             string   `json:"type"`
	Subtype          string   `json:"subtype"`
	Mask             *string  `json:"mask"`
	CurrentBalance   *float64 `json:"current_balance"`
	AvailableBalance *float64 `json:"available_balance"`
	IsoCurrencyCode  string   `json:"iso_currency_code"`
	AccountRole      *string  `json:"account_role"`
	CreatedAt        string   `json:"created_at"`
}

var validRoles = map[string]bool{
	"checking":    true,
	"savings":     true,
	"credit_card": true,
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}

func ListAccounts(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		rows, err := pool.Query(r.Context(), `
			SELECT a.id::text, a.plaid_item_id::text, a.user_id::text, a.plaid_account_id,
			       a.name, a.official_name, a.type, a.subtype, a.mask,
			       a.current_balance, a.available_balance, a.iso_currency_code,
			       a.created_at::text, ar.account_role
			FROM accounts a
			LEFT JOIN account_roles ar ON ar.account_id = a.id
			WHERE a.user_id = $1
			ORDER BY a.created_at
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query accounts")
			return
		}
		defer rows.Close()

		accounts := []accountWithRole{}
		for rows.Next() {
			var a accountWithRole
			if err := rows.Scan(
				&a.ID, &a.PlaidItemID, &a.UserID, &a.PlaidAccountID, &a.Name,
				&a.OfficialName, &a.Type, &a.Subtype, &a.Mask,
				&a.CurrentBalance, &a.AvailableBalance, &a.IsoCurrencyCode,
				&a.CreatedAt, &a.AccountRole,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan account")
				return
			}
			accounts = append(accounts, a)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"accounts": accounts})
	}
}

func UpdateAccountRole(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		accountID := chi.URLParam(r, "id")

		var body struct {
			AccountRole string `json:"account_role"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil || !validRoles[body.AccountRole] {
			writeError(w, http.StatusBadRequest, "account_role must be one of: checking, savings, credit_card")
			return
		}

		// Verify account belongs to user
		var exists bool
		err := pool.QueryRow(r.Context(),
			`SELECT EXISTS(SELECT 1 FROM accounts WHERE id = $1 AND user_id = $2)`,
			accountID, userID,
		).Scan(&exists)
		if err != nil || !exists {
			writeError(w, http.StatusNotFound, "account not found")
			return
		}

		// Upsert the role
		_, err = pool.Exec(r.Context(), `
			INSERT INTO account_roles (account_id, user_id, account_role)
			VALUES ($1, $2, $3)
			ON CONFLICT (account_id) DO UPDATE SET account_role = EXCLUDED.account_role
		`, accountID, userID, body.AccountRole)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to update account role")
			return
		}

		// Return the updated account
		var a accountWithRole
		err = pool.QueryRow(r.Context(), `
			SELECT a.id::text, a.plaid_item_id::text, a.user_id::text, a.plaid_account_id,
			       a.name, a.official_name, a.type, a.subtype, a.mask,
			       a.current_balance, a.available_balance, a.iso_currency_code,
			       a.created_at::text, ar.account_role
			FROM accounts a
			LEFT JOIN account_roles ar ON ar.account_id = a.id
			WHERE a.id = $1
		`, accountID).Scan(
			&a.ID, &a.PlaidItemID, &a.UserID, &a.PlaidAccountID, &a.Name,
			&a.OfficialName, &a.Type, &a.Subtype, &a.Mask,
			&a.CurrentBalance, &a.AvailableBalance, &a.IsoCurrencyCode,
			&a.CreatedAt, &a.AccountRole,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch updated account")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(a)
	}
}
