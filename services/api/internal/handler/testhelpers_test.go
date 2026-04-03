//go:build integration

package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/juliand71/flume/services/api/internal/auth"
)

type testTxn struct {
	Name     string
	Amount   float64
	Date     string
	Category *string
}

func setupTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()

	dbURL := os.Getenv("TEST_DATABASE_URL")
	if dbURL == "" {
		t.Fatal("TEST_DATABASE_URL is not set")
	}

	pool, err := pgxpool.New(context.Background(), dbURL)
	if err != nil {
		t.Fatalf("failed to create pool: %v", err)
	}

	if err := pool.Ping(context.Background()); err != nil {
		t.Fatalf("failed to ping database: %v", err)
	}

	t.Cleanup(func() {
		ctx := context.Background()
		tables := []string{
			"savings_goals",
			"account_roles",
			"budget_periods",
			"income_streams",
			"transactions",
			"accounts",
			"plaid_items",
			"category_mappings",
			"profiles",
		}
		for _, table := range tables {
			_, _ = pool.Exec(ctx, fmt.Sprintf("DELETE FROM %s", table))
		}
		_, _ = pool.Exec(ctx, "DELETE FROM auth.users")
		pool.Close()
	})

	return pool
}

func seedUser(t *testing.T, pool *pgxpool.Pool, userID string) {
	t.Helper()
	ctx := context.Background()

	_, err := pool.Exec(ctx, `INSERT INTO auth.users (id) VALUES ($1)`, userID)
	if err != nil {
		t.Fatalf("failed to seed auth.users: %v", err)
	}

	_, err = pool.Exec(ctx, `INSERT INTO profiles (id, onboarding_step) VALUES ($1, 'welcome')`, userID)
	if err != nil {
		t.Fatalf("failed to seed profiles: %v", err)
	}
}

func seedAccount(t *testing.T, pool *pgxpool.Pool, userID string) string {
	t.Helper()
	ctx := context.Background()

	plaidItemID := "00000000-0000-0000-0000-000000000010"
	// Use user-specific plaid_item_id to allow multiple users
	_, err := pool.Exec(ctx, `
		INSERT INTO plaid_items (id, user_id, plaid_item_id, access_token, institution_name)
		VALUES ($1, $2, 'plaid-item-' || $2, 'access-token-test', 'Test Bank')
		ON CONFLICT (id) DO NOTHING
	`, plaidItemID, userID)
	if err != nil {
		t.Fatalf("failed to seed plaid_items: %v", err)
	}

	var accountID string
	err = pool.QueryRow(ctx, `
		INSERT INTO accounts (plaid_item_id, user_id, plaid_account_id, name, type, subtype, iso_currency_code)
		VALUES ($1, $2, 'plaid-acct-' || $2, 'Test Checking', 'depository', 'checking', 'USD')
		RETURNING id::text
	`, plaidItemID, userID).Scan(&accountID)
	if err != nil {
		t.Fatalf("failed to seed accounts: %v", err)
	}

	return accountID
}

func seedTransactions(t *testing.T, pool *pgxpool.Pool, userID, accountID string, txns []testTxn) {
	t.Helper()
	ctx := context.Background()

	for i, txn := range txns {
		var categoryJSON *string
		if txn.Category != nil {
			s := fmt.Sprintf(`{"primary": "%s", "detailed": "%s_OTHER"}`, *txn.Category, *txn.Category)
			categoryJSON = &s
		}

		_, err := pool.Exec(ctx, `
			INSERT INTO transactions (account_id, user_id, plaid_transaction_id, name, amount, date, personal_finance_category)
			VALUES ($1, $2, $3, $4, $5, $6::date, $7::jsonb)
		`, accountID, userID, fmt.Sprintf("plaid-txn-%s-%d", accountID[:8], i), txn.Name, txn.Amount, txn.Date, categoryJSON)
		if err != nil {
			t.Fatalf("failed to seed transaction %d: %v", i, err)
		}
	}
}

func seedIncomeStream(t *testing.T, pool *pgxpool.Pool, userID string, name string, amount float64, freq string) string {
	t.Helper()
	ctx := context.Background()

	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO income_streams (user_id, name, estimated_amount, frequency)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text
	`, userID, name, amount, freq).Scan(&id)
	if err != nil {
		t.Fatalf("failed to seed income stream: %v", err)
	}
	return id
}

func seedBudgetPeriod(t *testing.T, pool *pgxpool.Pool, userID string, start, end string, incomeTarget float64) string {
	t.Helper()
	ctx := context.Background()

	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO budget_periods (user_id, start_date, end_date, income_target, fixed_target, flex_target, savings_target)
		VALUES ($1, $2::date, $3::date, $4, $5, $6, $7)
		RETURNING id::text
	`, userID, start, end, incomeTarget, incomeTarget*0.50, incomeTarget*0.30, incomeTarget*0.20).Scan(&id)
	if err != nil {
		t.Fatalf("failed to seed budget period: %v", err)
	}
	return id
}

func seedSavingsGoal(t *testing.T, pool *pgxpool.Pool, userID string, name string, targetAmount float64, isEmergency bool) string {
	t.Helper()
	ctx := context.Background()

	var id string
	err := pool.QueryRow(ctx, `
		INSERT INTO savings_goals (user_id, name, target_amount, is_emergency_fund)
		VALUES ($1, $2, $3, $4)
		RETURNING id::text
	`, userID, name, targetAmount, isEmergency).Scan(&id)
	if err != nil {
		t.Fatalf("failed to seed savings goal: %v", err)
	}
	return id
}

func seedCategoryMappings(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()

	_, err := pool.Exec(ctx, `
		INSERT INTO category_mappings (user_id, plaid_primary_category, plaid_detailed_category, budget_category) VALUES
			(null, 'INCOME', null, 'income'),
			(null, 'RENT_AND_UTILITIES', null, 'fixed'),
			(null, 'LOAN_PAYMENTS', null, 'fixed'),
			(null, 'HOME_IMPROVEMENT', null, 'fixed'),
			(null, 'FOOD_AND_DRINK', null, 'flex'),
			(null, 'GENERAL_MERCHANDISE', null, 'flex'),
			(null, 'ENTERTAINMENT', null, 'flex'),
			(null, 'PERSONAL_CARE', null, 'flex'),
			(null, 'GENERAL_SERVICES', null, 'flex'),
			(null, 'TRANSPORTATION', null, 'flex'),
			(null, 'TRAVEL', null, 'flex'),
			(null, 'MEDICAL', null, 'flex'),
			(null, 'GOVERNMENT_AND_NON_PROFIT', null, 'flex'),
			(null, 'TRANSFER_IN', null, 'transfer'),
			(null, 'TRANSFER_OUT', null, 'transfer'),
			(null, 'BANK_FEES', null, 'fixed')
		ON CONFLICT ON CONSTRAINT category_mappings_unique DO NOTHING
	`)
	if err != nil {
		t.Fatalf("failed to seed category mappings: %v", err)
	}
}

func makeAuthRequest(method, path string, body any, userID string) *http.Request {
	var reqBody *bytes.Buffer
	if body != nil {
		b, _ := json.Marshal(body)
		reqBody = bytes.NewBuffer(b)
	} else {
		reqBody = bytes.NewBuffer(nil)
	}

	req := httptest.NewRequest(method, path, reqBody)
	req.Header.Set("Content-Type", "application/json")

	ctx := context.WithValue(req.Context(), auth.UserIDKey, userID)
	return req.WithContext(ctx)
}

func execHandler(t *testing.T, handler http.HandlerFunc, req *http.Request) *httptest.ResponseRecorder {
	t.Helper()
	rr := httptest.NewRecorder()
	handler.ServeHTTP(rr, req)
	return rr
}
