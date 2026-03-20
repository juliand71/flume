package handler

import (
	"encoding/json"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

var onboardingStepOrder = []string{
	"welcome", "link_bank", "syncing", "confirm_income",
	"create_budget", "savings_goal", "complete",
}

func stepIndex(step string) int {
	for i, s := range onboardingStepOrder {
		if s == step {
			return i
		}
	}
	return -1
}

type onboardingStatus struct {
	OnboardingStep   *string `json:"onboarding_step"`
	HasPlaidItems    bool    `json:"has_plaid_items"`
	TransactionCount int     `json:"transaction_count"`
	HasIncomeStreams bool    `json:"has_income_streams"`
	HasBudgetPeriod  bool    `json:"has_budget_period"`
	HasSavingsGoal   bool    `json:"has_savings_goal"`
}

func GetOnboardingStatus(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var status onboardingStatus
		err := pool.QueryRow(r.Context(), `
			SELECT
				p.onboarding_step,
				EXISTS(SELECT 1 FROM plaid_items WHERE user_id = $1) as has_plaid_items,
				(SELECT count(*) FROM transactions WHERE user_id = $1)::int as transaction_count,
				EXISTS(SELECT 1 FROM income_streams WHERE user_id = $1 AND active = true) as has_income_streams,
				EXISTS(SELECT 1 FROM budget_periods WHERE user_id = $1) as has_budget_period,
				EXISTS(SELECT 1 FROM savings_goals WHERE user_id = $1 AND NOT archived) as has_savings_goal
			FROM profiles p
			WHERE p.id = $1
		`, userID).Scan(
			&status.OnboardingStep,
			&status.HasPlaidItems,
			&status.TransactionCount,
			&status.HasIncomeStreams,
			&status.HasBudgetPeriod,
			&status.HasSavingsGoal,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch onboarding status")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(status)
	}
}

func UpdateOnboardingStep(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			Step string `json:"step"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}

		newIndex := stepIndex(body.Step)
		if newIndex < 0 {
			writeError(w, http.StatusBadRequest, "invalid onboarding step")
			return
		}

		// Fetch current step and validate forward-only transition
		var currentStep *string
		err := pool.QueryRow(r.Context(), `
			SELECT onboarding_step FROM profiles WHERE id = $1
		`, userID).Scan(&currentStep)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch current step")
			return
		}

		if currentStep != nil {
			currentIndex := stepIndex(*currentStep)
			if currentIndex >= 0 && newIndex < currentIndex {
				writeError(w, http.StatusBadRequest, "cannot move to a previous onboarding step")
				return
			}
		}

		// Update step
		_, err = pool.Exec(r.Context(), `
			UPDATE profiles SET onboarding_step = $2 WHERE id = $1
		`, userID, body.Step)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to update onboarding step")
			return
		}

		// Return updated status
		var status onboardingStatus
		err = pool.QueryRow(r.Context(), `
			SELECT
				p.onboarding_step,
				EXISTS(SELECT 1 FROM plaid_items WHERE user_id = $1) as has_plaid_items,
				(SELECT count(*) FROM transactions WHERE user_id = $1)::int as transaction_count,
				EXISTS(SELECT 1 FROM income_streams WHERE user_id = $1 AND active = true) as has_income_streams,
				EXISTS(SELECT 1 FROM budget_periods WHERE user_id = $1) as has_budget_period,
				EXISTS(SELECT 1 FROM savings_goals WHERE user_id = $1 AND NOT archived) as has_savings_goal
			FROM profiles p
			WHERE p.id = $1
		`, userID).Scan(
			&status.OnboardingStep,
			&status.HasPlaidItems,
			&status.TransactionCount,
			&status.HasIncomeStreams,
			&status.HasBudgetPeriod,
			&status.HasSavingsGoal,
		)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to fetch onboarding status")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(status)
	}
}
