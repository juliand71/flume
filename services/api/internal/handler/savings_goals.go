package handler

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/juliand71/flume/services/api/internal/auth"
)

type savingsGoal struct {
	ID              string  `json:"id"`
	UserID          string  `json:"user_id"`
	Name            string  `json:"name"`
	TargetAmount    float64 `json:"target_amount"`
	CurrentAmount   float64 `json:"current_amount"`
	Spent           float64 `json:"spent"`
	Balance         float64 `json:"balance"`
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
			SELECT `+savingsGoalColumns+`, COALESCE(linked.total, 0) as spent
			FROM savings_goals
			LEFT JOIN (
				SELECT savings_goal_id, SUM(amount) as total
				FROM transactions_with_category
				WHERE budget_category = 'savings' AND savings_goal_id IS NOT NULL
				GROUP BY savings_goal_id
			) linked ON linked.savings_goal_id = savings_goals.id
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
			var g savingsGoal
			if err := rows.Scan(&g.ID, &g.UserID, &g.Name, &g.TargetAmount, &g.CurrentAmount,
				&g.Emoji, &g.IsEmergencyFund, &g.Priority, &g.Archived, &g.CreatedAt,
				&g.Spent); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan savings goal")
				return
			}
			g.Balance = g.CurrentAmount - g.Spent
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
			BudgetPeriodID string `json:"budget_period_id"`
			Allocations    []struct {
				SavingsGoalID string  `json:"savings_goal_id"`
				Amount        float64 `json:"amount"`
			} `json:"allocations"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.BudgetPeriodID == "" {
			writeError(w, http.StatusBadRequest, "budget_period_id is required")
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

		// Verify the budget period is current (not past)
		var periodExists bool
		err := pool.QueryRow(r.Context(), `
			SELECT EXISTS(
				SELECT 1 FROM budget_periods
				WHERE id = $1 AND user_id = $2
				AND start_date <= CURRENT_DATE AND end_date > CURRENT_DATE
			)
		`, body.BudgetPeriodID, userID).Scan(&periodExists)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to verify budget period")
			return
		}
		if !periodExists {
			writeError(w, http.StatusBadRequest, "can only fund goals from the current budget period")
			return
		}

		tx, err := pool.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to begin transaction")
			return
		}
		defer tx.Rollback(r.Context())

		// Lock the budget period row to serialize concurrent fill requests
		_, err = tx.Exec(r.Context(), `
			SELECT 1 FROM budget_periods WHERE id = $1 AND user_id = $2 FOR UPDATE
		`, body.BudgetPeriodID, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to lock budget period")
			return
		}

		// Compute effective surplus and validate allocations don't exceed it
		var totalRequested float64
		for _, a := range body.Allocations {
			totalRequested += a.Amount
		}

		var effectiveSurplus float64
		err = tx.QueryRow(r.Context(), `
			SELECT
				-(coalesce(sum(t.amount) FILTER (WHERE t.budget_category = 'income'), 0))
				- coalesce(sum(t.amount) FILTER (WHERE t.budget_category = 'fixed'), 0)
				- coalesce(sum(t.amount) FILTER (WHERE t.budget_category = 'flex'), 0)
				- coalesce((SELECT sum(amount) FROM savings_goal_allocations WHERE type = 'fill' AND user_id = $1 AND budget_period_id = $2::uuid), 0)
				+ bp.carryover_amount
			FROM budget_periods bp
			LEFT JOIN transactions_with_category t
				ON t.user_id = bp.user_id AND t.date >= bp.start_date::date AND t.date < bp.end_date::date
			WHERE bp.id = $2 AND bp.user_id = $1
			GROUP BY bp.carryover_amount
		`, userID, body.BudgetPeriodID).Scan(&effectiveSurplus)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to compute surplus")
			return
		}

		if totalRequested > effectiveSurplus+0.01 {
			writeError(w, http.StatusUnprocessableEntity, "total allocations exceed available surplus")
			return
		}

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

			// Record the allocation against this budget period
			_, err = tx.Exec(r.Context(), `
				INSERT INTO savings_goal_allocations (user_id, budget_period_id, savings_goal_id, amount, type)
				VALUES ($1, $2, $3, $4, 'fill')
			`, userID, body.BudgetPeriodID, a.SavingsGoalID, a.Amount)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to record allocation")
				return
			}
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to commit transaction")
			return
		}

		// Return updated goals list
		rows, err := pool.Query(r.Context(), `
			SELECT `+savingsGoalColumns+`, COALESCE(linked.total, 0) as spent
			FROM savings_goals
			LEFT JOIN (
				SELECT savings_goal_id, SUM(amount) as total
				FROM transactions_with_category
				WHERE budget_category = 'savings' AND savings_goal_id IS NOT NULL
				GROUP BY savings_goal_id
			) linked ON linked.savings_goal_id = savings_goals.id
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
			var g savingsGoal
			if err := rows.Scan(&g.ID, &g.UserID, &g.Name, &g.TargetAmount, &g.CurrentAmount,
				&g.Emoji, &g.IsEmergencyFund, &g.Priority, &g.Archived, &g.CreatedAt,
				&g.Spent); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan savings goal")
				return
			}
			g.Balance = g.CurrentAmount - g.Spent
			goals = append(goals, g)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"savings_goals": goals})
	}
}

func WithdrawSavingsGoals(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		var body struct {
			BudgetPeriodID string `json:"budget_period_id"`
			Withdrawals    []struct {
				SavingsGoalID string  `json:"savings_goal_id"`
				Amount        float64 `json:"amount"`
			} `json:"withdrawals"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
		if body.BudgetPeriodID == "" {
			writeError(w, http.StatusBadRequest, "budget_period_id is required")
			return
		}
		if len(body.Withdrawals) == 0 {
			writeError(w, http.StatusBadRequest, "withdrawals is required")
			return
		}
		for _, wd := range body.Withdrawals {
			if wd.SavingsGoalID == "" {
				writeError(w, http.StatusBadRequest, "savings_goal_id is required for each withdrawal")
				return
			}
			if wd.Amount <= 0 {
				writeError(w, http.StatusBadRequest, "amount must be positive for each withdrawal")
				return
			}
		}

		// Verify the period is current
		var periodExists bool
		err := pool.QueryRow(r.Context(), `
			SELECT EXISTS(
				SELECT 1 FROM budget_periods
				WHERE id = $1 AND user_id = $2
				AND start_date <= CURRENT_DATE AND end_date > CURRENT_DATE
			)
		`, body.BudgetPeriodID, userID).Scan(&periodExists)
		if err != nil || !periodExists {
			writeError(w, http.StatusBadRequest, "can only withdraw from the current budget period")
			return
		}

		// Get the period to check effective surplus (must be negative = deficit)
		var p budgetPeriod
		err = pool.QueryRow(r.Context(), `
			SELECT id::text, user_id::text, start_date::text, end_date::text,
			       income_target, fixed_target, flex_target, savings_target,
			       income_stream_id::text, carryover_amount, created_at::text
			FROM budget_periods
			WHERE id = $1 AND user_id = $2
		`, body.BudgetPeriodID, userID).Scan(
			&p.ID, &p.UserID, &p.StartDate, &p.EndDate,
			&p.IncomeTarget, &p.FixedTarget, &p.FlexTarget, &p.SavingsTarget,
			&p.IncomeStreamID, &p.CarryoverAmount, &p.CreatedAt,
		)
		if err != nil {
			writeError(w, http.StatusNotFound, "budget period not found")
			return
		}

		actuals, err := periodWithActuals(r.Context(), pool, &p)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to compute actuals")
			return
		}

		if actuals.EffectiveSurplus >= 0 {
			writeError(w, http.StatusBadRequest, "no deficit to cover — effective surplus is not negative")
			return
		}

		deficit := -actuals.EffectiveSurplus // positive number representing deficit
		var totalWithdrawal float64
		for _, wd := range body.Withdrawals {
			totalWithdrawal += wd.Amount
		}
		if totalWithdrawal > deficit {
			writeError(w, http.StatusBadRequest, "total withdrawal exceeds deficit")
			return
		}

		// Validate each goal's balance
		for _, wd := range body.Withdrawals {
			var currentAmount float64
			var spent float64
			err := pool.QueryRow(r.Context(), `
				SELECT sg.current_amount, COALESCE(linked.total, 0)
				FROM savings_goals sg
				LEFT JOIN (
					SELECT savings_goal_id, SUM(amount) as total
					FROM transactions_with_category
					WHERE budget_category = 'savings' AND savings_goal_id IS NOT NULL
					GROUP BY savings_goal_id
				) linked ON linked.savings_goal_id = sg.id
				WHERE sg.id = $1 AND sg.user_id = $2 AND sg.archived = false
			`, wd.SavingsGoalID, userID).Scan(&currentAmount, &spent)
			if err != nil {
				writeError(w, http.StatusNotFound, "savings goal not found: "+wd.SavingsGoalID)
				return
			}
			balance := currentAmount - spent
			if wd.Amount > balance {
				writeError(w, http.StatusBadRequest, "withdrawal exceeds goal balance for: "+wd.SavingsGoalID)
				return
			}
		}

		// Execute withdrawal in a transaction
		tx, err := pool.Begin(r.Context())
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to begin transaction")
			return
		}
		defer tx.Rollback(r.Context())

		for _, wd := range body.Withdrawals {
			// Decrement savings goal current_amount
			_, err := tx.Exec(r.Context(), `
				UPDATE savings_goals SET current_amount = current_amount - $3
				WHERE id = $1 AND user_id = $2
			`, wd.SavingsGoalID, userID, wd.Amount)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to update savings goal")
				return
			}

			// Record withdrawal allocation
			_, err = tx.Exec(r.Context(), `
				INSERT INTO savings_goal_allocations (user_id, budget_period_id, savings_goal_id, amount, type)
				VALUES ($1, $2, $3, $4, 'withdrawal')
			`, userID, body.BudgetPeriodID, wd.SavingsGoalID, wd.Amount)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to record withdrawal")
				return
			}
		}

		// Increase carryover_amount to reduce the deficit
		_, err = tx.Exec(r.Context(), `
			UPDATE budget_periods SET carryover_amount = carryover_amount + $2
			WHERE id = $1
		`, body.BudgetPeriodID, totalWithdrawal)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to update carryover")
			return
		}

		if err := tx.Commit(r.Context()); err != nil {
			writeError(w, http.StatusInternalServerError, "failed to commit transaction")
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"success": true})
	}
}

func ListSavingsGoalTransactions(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		goalID := chi.URLParam(r, "id")

		rows, err := pool.Query(r.Context(), `
			SELECT t.id::text, t.account_id::text, t.name, t.amount,
			       t.iso_currency_code, t.date::text, t.pending,
			       t.budget_category, t.category_override, t.savings_goal_id::text
			FROM transactions_with_category t
			WHERE t.user_id = $1
			  AND t.savings_goal_id = $2::uuid
			  AND t.budget_category = 'savings'
			ORDER BY t.date DESC, t.name
		`, userID, goalID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query transactions")
			return
		}
		defer rows.Close()

		transactions := []budgetTransaction{}
		for rows.Next() {
			var t budgetTransaction
			if err := rows.Scan(
				&t.ID, &t.AccountID, &t.Name, &t.Amount,
				&t.IsoCurrencyCode, &t.Date, &t.Pending,
				&t.BudgetCategory, &t.CategoryOverride, &t.SavingsGoalID,
			); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan transaction")
				return
			}
			transactions = append(transactions, t)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"transactions": transactions})
	}
}

type savingsGoalAllocation struct {
	ID            string  `json:"id"`
	SavingsGoalID string  `json:"savings_goal_id"`
	GoalName      string  `json:"goal_name"`
	GoalEmoji     *string `json:"goal_emoji"`
	Amount        float64 `json:"amount"`
	Type          string  `json:"type"`
	CreatedAt     string  `json:"created_at"`
}

func ListPeriodAllocations(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())
		periodID := chi.URLParam(r, "id")

		rows, err := pool.Query(r.Context(), `
			SELECT sga.id::text, sga.savings_goal_id::text, sg.name, sg.emoji,
			       sga.amount, sga.type, sga.created_at::text
			FROM savings_goal_allocations sga
			JOIN savings_goals sg ON sg.id = sga.savings_goal_id
			WHERE sga.user_id = $1 AND sga.budget_period_id = $2
			ORDER BY sga.created_at
		`, userID, periodID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query allocations")
			return
		}
		defer rows.Close()

		allocations := []savingsGoalAllocation{}
		for rows.Next() {
			var a savingsGoalAllocation
			if err := rows.Scan(&a.ID, &a.SavingsGoalID, &a.GoalName, &a.GoalEmoji, &a.Amount, &a.Type, &a.CreatedAt); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan allocation")
				return
			}
			allocations = append(allocations, a)
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{"allocations": allocations})
	}
}
