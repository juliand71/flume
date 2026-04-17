//go:build integration

package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"

	"github.com/go-chi/chi/v5"
)

func withRouteContext(ctx context.Context, rctx *chi.Context) context.Context {
	return context.WithValue(ctx, chi.RouteCtxKey, rctx)
}

const testUserID = "00000000-0000-0000-0000-000000000001"

// --- Onboarding ---

func TestIntegration_GetOnboardingStatus(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	req := makeAuthRequest("GET", "/onboarding/status", nil, testUserID)
	rr := execHandler(t, GetOnboardingStatus(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var status onboardingStatus
	json.NewDecoder(rr.Body).Decode(&status)
	if status.OnboardingStep == nil || *status.OnboardingStep != "welcome" {
		t.Errorf("expected step=welcome, got %v", status.OnboardingStep)
	}
}

func TestIntegration_UpdateOnboardingStep_Forward(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]string{"step": "link_bank"}
	req := makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
	rr := execHandler(t, UpdateOnboardingStep(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var status onboardingStatus
	json.NewDecoder(rr.Body).Decode(&status)
	if status.OnboardingStep == nil || *status.OnboardingStep != "link_bank" {
		t.Errorf("expected step=link_bank, got %v", status.OnboardingStep)
	}
}

func TestIntegration_UpdateOnboardingStep_Backward(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	// First advance to link_bank
	body := map[string]string{"step": "link_bank"}
	req := makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
	execHandler(t, UpdateOnboardingStep(pool), req)

	// Try going back to welcome
	body = map[string]string{"step": "welcome"}
	req = makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
	rr := execHandler(t, UpdateOnboardingStep(pool), req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for backward step, got %d", rr.Code)
	}
}

func TestIntegration_UpdateOnboardingStep_Invalid(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]string{"step": "nonexistent_step"}
	req := makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
	rr := execHandler(t, UpdateOnboardingStep(pool), req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for invalid step, got %d", rr.Code)
	}
}

// --- Accounts ---

func TestIntegration_ListAccounts(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	seedAccount(t, pool, testUserID)

	req := makeAuthRequest("GET", "/budget/accounts", nil, testUserID)
	rr := execHandler(t, ListAccounts(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp struct {
		Accounts []json.RawMessage `json:"accounts"`
	}
	json.NewDecoder(rr.Body).Decode(&resp)
	if len(resp.Accounts) == 0 {
		t.Error("expected at least one account")
	}
}

func TestIntegration_UpdateAccountRole(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	body := map[string]string{"account_role": "primary"}
	req := makeAuthRequest("PATCH", "/budget/accounts/"+accountID+"/role", body, testUserID)

	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", accountID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))

	rr := execHandler(t, UpdateAccountRole(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

// --- Income Streams CRUD ---

func TestIntegration_IncomeStreams_CRUD(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	// Create
	createBody := map[string]any{
		"name":             "Salary",
		"estimated_amount": 5000.0,
		"frequency":        "monthly",
	}
	req := makeAuthRequest("POST", "/budget/income-streams", createBody, testUserID)
	rr := execHandler(t, CreateIncomeStream(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&created)

	// List
	req = makeAuthRequest("GET", "/budget/income-streams", nil, testUserID)
	rr = execHandler(t, ListIncomeStreams(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d", rr.Code)
	}

	// Update
	updateBody := map[string]any{"name": "Updated Salary"}
	req = makeAuthRequest("PATCH", "/budget/income-streams/"+created.ID, updateBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", created.ID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, UpdateIncomeStream(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("update: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Delete
	req = makeAuthRequest("DELETE", "/budget/income-streams/"+created.ID, nil, testUserID)
	rctx = chi.NewRouteContext()
	rctx.URLParams.Add("id", created.ID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, DeleteIncomeStream(pool), req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("delete: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_CreateIncomeStream_MissingName(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]any{"estimated_amount": 5000.0, "frequency": "monthly"}
	req := makeAuthRequest("POST", "/budget/income-streams", body, testUserID)
	rr := execHandler(t, CreateIncomeStream(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for missing name, got %d", rr.Code)
	}
}

func TestIntegration_CreateIncomeStream_InvalidFrequency(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]any{"name": "Test", "estimated_amount": 5000.0, "frequency": "invalid"}
	req := makeAuthRequest("POST", "/budget/income-streams", body, testUserID)
	rr := execHandler(t, CreateIncomeStream(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for invalid freq, got %d", rr.Code)
	}
}

// --- Budget Periods ---

func TestIntegration_BudgetPeriods_CRUD(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	// Create
	createBody := map[string]any{
		"start_date":     "2026-04-01",
		"end_date":       "2026-05-01",
		"income_target":  5000.0,
		"fixed_target":   2500.0,
		"flex_target":    1500.0,
		"savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&created)

	// Get current period
	req = makeAuthRequest("GET", "/budget/current-period", nil, testUserID)
	rr = execHandler(t, GetCurrentPeriod(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("current-period: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// List periods
	req = makeAuthRequest("GET", "/budget/periods?limit=10&offset=0", nil, testUserID)
	rr = execHandler(t, ListPeriods(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d", rr.Code)
	}

	// Update
	updateBody := map[string]any{"income_target": 5500.0}
	req = makeAuthRequest("PATCH", "/budget/periods/"+created.ID, updateBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", created.ID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, UpdatePeriod(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("update: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_CreatePeriod_EndBeforeStart(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]any{
		"start_date":     "2026-05-01",
		"end_date":       "2026-04-01",
		"income_target":  5000.0,
		"fixed_target":   2500.0,
		"flex_target":    1500.0,
		"savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", body, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for end <= start, got %d", rr.Code)
	}
}

// --- Detection Endpoints ---

func TestIntegration_DetectIncome_BiweeklyPaycheck(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	txns := []testTxn{
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2026-01-15"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2026-01-29"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2026-02-12"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2026-02-26"},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	req := makeAuthRequest("GET", "/budget/detect-income", nil, testUserID)
	rr := execHandler(t, DetectIncome(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp incomeDetectionResponse
	json.NewDecoder(rr.Body).Decode(&resp)

	if len(resp.DetectedStreams) == 0 {
		t.Fatal("expected at least one detected stream")
	}

	stream := resp.DetectedStreams[0]
	if stream.Frequency != "biweekly" {
		t.Errorf("expected frequency=biweekly, got %s", stream.Frequency)
	}
	if stream.Confidence != "high" {
		t.Errorf("expected confidence=high, got %s", stream.Confidence)
	}
	if stream.EstimatedAmount != 2800 {
		t.Errorf("expected amount=2800, got %v", stream.EstimatedAmount)
	}
}

func TestIntegration_DetectIncome_ExpandedSearch(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	// Seed transactions outside the query date range
	txns := []testTxn{
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2025-06-15"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2025-06-29"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2025-07-13"},
		{Name: "ACME CORP PAYROLL", Amount: -2800, Date: "2025-07-27"},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	req := makeAuthRequest("GET", "/budget/detect-income?start_date=2026-04-01&end_date=2026-05-01", nil, testUserID)
	rr := execHandler(t, DetectIncome(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp incomeDetectionResponse
	json.NewDecoder(rr.Body).Decode(&resp)
	if !resp.ExpandedSearch {
		t.Error("expected expanded_search=true")
	}
}

func TestIntegration_DetectFixed(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	rent := "RENT_AND_UTILITIES"
	txns := []testTxn{
		{Name: "CITY POWER CO", Amount: 120, Date: "2026-04-01", Category: &rent},
		{Name: "CITY POWER CO", Amount: 120, Date: "2026-03-01", Category: &rent},
		{Name: "CITY POWER CO", Amount: 120, Date: "2026-02-01", Category: &rent},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)
	seedCategoryMappings(t, pool)

	req := makeAuthRequest("GET", "/budget/detect-fixed?start_date=2026-01-01&end_date=2026-05-01", nil, testUserID)
	rr := execHandler(t, DetectFixed(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_DetectFlex(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	food := "FOOD_AND_DRINK"
	txns := []testTxn{
		{Name: "COFFEE SHOP", Amount: 5.50, Date: "2026-04-02", Category: &food},
		{Name: "GROCERY STORE", Amount: 85.00, Date: "2026-04-05", Category: &food},
		{Name: "RESTAURANT", Amount: 42.00, Date: "2026-04-10", Category: &food},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)
	seedCategoryMappings(t, pool)

	req := makeAuthRequest("GET", "/budget/detect-flex?start_date=2026-04-01&end_date=2026-05-01", nil, testUserID)
	rr := execHandler(t, DetectFlex(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var resp flexDetectionResponse
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp.TransactionCount != 3 {
		t.Errorf("expected 3 transactions, got %d", resp.TransactionCount)
	}
}

// --- Budget Suggestion ---

func TestIntegration_SuggestPeriod(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	streamID := seedIncomeStream(t, pool, testUserID, "Salary", 5000, "monthly")

	body := map[string]string{"income_stream_id": streamID}
	req := makeAuthRequest("POST", "/budget/suggest-period", body, testUserID)
	rr := execHandler(t, SuggestPeriod(pool), req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var suggestion budgetSuggestion
	json.NewDecoder(rr.Body).Decode(&suggestion)
	if suggestion.IncomeTarget != 5000 {
		t.Errorf("expected income_target=5000, got %v", suggestion.IncomeTarget)
	}
	if suggestion.FixedTarget != 2500 {
		t.Errorf("expected fixed_target=2500, got %v", suggestion.FixedTarget)
	}
	if suggestion.FlexTarget != 1500 {
		t.Errorf("expected flex_target=1500, got %v", suggestion.FlexTarget)
	}
	if suggestion.SavingsTarget != 1000 {
		t.Errorf("expected savings_target=1000, got %v", suggestion.SavingsTarget)
	}
}

func TestIntegration_SuggestPeriod_MissingStreamID(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]string{}
	req := makeAuthRequest("POST", "/budget/suggest-period", body, testUserID)
	rr := execHandler(t, SuggestPeriod(pool), req)

	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rr.Code)
	}
}

func TestIntegration_SuggestPeriod_NonexistentStream(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	body := map[string]string{"income_stream_id": "00000000-0000-0000-0000-000000000099"}
	req := makeAuthRequest("POST", "/budget/suggest-period", body, testUserID)
	rr := execHandler(t, SuggestPeriod(pool), req)

	if rr.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rr.Code)
	}
}

// --- Transactions ---

func TestIntegration_Transactions(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	periodID := seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)
	seedCategoryMappings(t, pool)

	food := "FOOD_AND_DRINK"
	txns := []testTxn{
		{Name: "GROCERY STORE", Amount: 85.00, Date: "2026-04-05", Category: &food},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// List transactions
	req := makeAuthRequest("GET", fmt.Sprintf("/budget/transactions?period_id=%s", periodID), nil, testUserID)
	rr := execHandler(t, ListTransactions(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	var listResp struct {
		Transactions []struct {
			ID string `json:"id"`
		} `json:"transactions"`
	}
	json.NewDecoder(rr.Body).Decode(&listResp)

	if len(listResp.Transactions) == 0 {
		t.Fatal("expected at least one transaction")
	}

	// Override category
	txID := listResp.Transactions[0].ID
	overrideBody := map[string]string{"budget_category": "fixed"}
	req = makeAuthRequest("POST", "/budget/transactions/"+txID+"/override", overrideBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", txID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, OverrideTransactionCategory(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("override: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_OverrideTransaction_InvalidCategory(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)

	food := "FOOD_AND_DRINK"
	txns := []testTxn{{Name: "TEST", Amount: 10, Date: "2026-04-05", Category: &food}}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Get transaction ID
	req := makeAuthRequest("GET", "/budget/transactions?period_id=whatever", nil, testUserID)
	// Just test the invalid category path with a made-up ID
	overrideBody := map[string]string{"budget_category": "invalid_category"}
	req = makeAuthRequest("POST", "/budget/transactions/00000000-0000-0000-0000-000000000099/override", overrideBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", "00000000-0000-0000-0000-000000000099")
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr := execHandler(t, OverrideTransactionCategory(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for invalid category, got %d", rr.Code)
	}
}

// --- Category Mappings ---

func TestIntegration_CategoryMappings(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	seedCategoryMappings(t, pool)

	// List
	req := makeAuthRequest("GET", "/budget/categories", nil, testUserID)
	rr := execHandler(t, ListCategoryMappings(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d", rr.Code)
	}

	// Create user mapping
	body := map[string]string{
		"plaid_primary_category": "ENTERTAINMENT",
		"budget_category":        "fixed",
	}
	req = makeAuthRequest("POST", "/budget/categories", body, testUserID)
	rr = execHandler(t, CreateCategoryMapping(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
}

// --- Category Summary ---

func TestIntegration_CategorySummary(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)
	seedCategoryMappings(t, pool)

	food := "FOOD_AND_DRINK"
	txns := []testTxn{
		{Name: "GROCERY STORE", Amount: 85.00, Date: "2026-04-05", Category: &food},
		{Name: "RESTAURANT", Amount: 42.00, Date: "2026-04-10", Category: &food},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	req := makeAuthRequest("GET", "/budget/category-summary", nil, testUserID)
	rr := execHandler(t, GetCategorySummary(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_CategorySummary_NoPeriod(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	req := makeAuthRequest("GET", "/budget/category-summary", nil, testUserID)
	rr := execHandler(t, GetCategorySummary(pool), req)
	if rr.Code != http.StatusNotFound {
		t.Errorf("expected 404 with no period, got %d", rr.Code)
	}
}

// --- Savings Goals ---

func TestIntegration_SavingsGoals_CRUD(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	// Create
	createBody := map[string]any{
		"name":              "Emergency Fund",
		"target_amount":     10000.0,
		"is_emergency_fund": true,
		"priority":          0,
	}
	req := makeAuthRequest("POST", "/budget/savings-goals", createBody, testUserID)
	rr := execHandler(t, CreateSavingsGoal(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&created)

	// List
	req = makeAuthRequest("GET", "/budget/savings-goals", nil, testUserID)
	rr = execHandler(t, ListSavingsGoals(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("list: expected 200, got %d", rr.Code)
	}

	// Update
	updateBody := map[string]any{"name": "Updated Fund"}
	req = makeAuthRequest("PATCH", "/budget/savings-goals/"+created.ID, updateBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", created.ID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, UpdateSavingsGoal(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("update: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Delete
	req = makeAuthRequest("DELETE", "/budget/savings-goals/"+created.ID, nil, testUserID)
	rctx = chi.NewRouteContext()
	rctx.URLParams.Add("id", created.ID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, DeleteSavingsGoal(pool), req)
	if rr.Code != http.StatusNoContent {
		t.Fatalf("delete: expected 204, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_FillSavingsGoals(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	goalID := seedSavingsGoal(t, pool, testUserID, "Emergency Fund", 10000, true)

	body := map[string]any{
		"allocations": []map[string]any{
			{"savings_goal_id": goalID, "amount": 500.0},
		},
	}
	req := makeAuthRequest("POST", "/budget/savings-goals/fill", body, testUserID)
	rr := execHandler(t, FillSavingsGoals(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("fill: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

// --- Sync Status ---

func TestIntegration_SyncStatus_WithPlaidItems(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	seedAccount(t, pool, testUserID) // also seeds plaid_item

	req := makeAuthRequest("GET", "/budget/sync-status", nil, testUserID)
	rr := execHandler(t, GetSyncStatus(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	var resp struct {
		HasPlaidItems    bool `json:"has_plaid_items"`
		TransactionCount int  `json:"transaction_count"`
	}
	json.NewDecoder(rr.Body).Decode(&resp)
	if !resp.HasPlaidItems {
		t.Error("expected has_plaid_items=true")
	}
}

func TestIntegration_SyncStatus_NoPlaidItems(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)

	req := makeAuthRequest("GET", "/budget/sync-status", nil, testUserID)
	rr := execHandler(t, GetSyncStatus(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rr.Code)
	}

	var resp struct {
		HasPlaidItems bool `json:"has_plaid_items"`
	}
	json.NewDecoder(rr.Body).Decode(&resp)
	if resp.HasPlaidItems {
		t.Error("expected has_plaid_items=false")
	}
}

// --- End-to-End Onboarding Flow ---

func TestIntegration_EndToEndOnboarding(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)

	// 1. Check initial status
	req := makeAuthRequest("GET", "/onboarding/status", nil, testUserID)
	rr := execHandler(t, GetOnboardingStatus(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("status: got %d", rr.Code)
	}

	// 2. Advance through steps
	steps := []string{"link_bank", "syncing", "choose_period"}
	for _, step := range steps {
		body := map[string]string{"step": step}
		req = makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
		rr = execHandler(t, UpdateOnboardingStep(pool), req)
		if rr.Code != http.StatusOK {
			t.Fatalf("advance to %s: got %d: %s", step, rr.Code, rr.Body.String())
		}
	}

	// 3. Seed income transactions
	txns := []testTxn{
		{Name: "ACME PAYROLL", Amount: -5000, Date: "2026-03-01"},
		{Name: "ACME PAYROLL", Amount: -5000, Date: "2026-03-31"},
		{Name: "ACME PAYROLL", Amount: -5000, Date: "2026-04-30"},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// 4. Detect income
	req = makeAuthRequest("GET", "/budget/detect-income", nil, testUserID)
	rr = execHandler(t, DetectIncome(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("detect income: got %d", rr.Code)
	}

	// 5. Create income stream and advance
	createStreamBody := map[string]any{
		"name":             "ACME PAYROLL",
		"estimated_amount": 5000.0,
		"frequency":        "monthly",
	}
	req = makeAuthRequest("POST", "/budget/income-streams", createStreamBody, testUserID)
	rr = execHandler(t, CreateIncomeStream(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create stream: got %d: %s", rr.Code, rr.Body.String())
	}

	var stream struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&stream)

	// 6. Advance to confirm_income, confirm_fixed, confirm_flex, review_savings
	for _, step := range []string{"confirm_income", "confirm_fixed", "confirm_flex", "review_savings"} {
		body := map[string]string{"step": step}
		req = makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
		execHandler(t, UpdateOnboardingStep(pool), req)
	}

	// 7. Create budget period
	periodBody := map[string]any{
		"start_date":       "2026-04-01",
		"end_date":         "2026-05-01",
		"income_target":    5000.0,
		"fixed_target":     2500.0,
		"flex_target":      1500.0,
		"savings_target":   1000.0,
		"income_stream_id": stream.ID,
	}
	req = makeAuthRequest("POST", "/budget/periods", periodBody, testUserID)
	rr = execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create period: got %d: %s", rr.Code, rr.Body.String())
	}

	// 8. Create savings goal and advance
	body := map[string]string{"step": "savings_goal"}
	req = makeAuthRequest("PATCH", "/onboarding/step", body, testUserID)
	execHandler(t, UpdateOnboardingStep(pool), req)

	goalBody := map[string]any{
		"name":              "Emergency Fund",
		"target_amount":     10000.0,
		"is_emergency_fund": true,
		"priority":          0,
	}
	req = makeAuthRequest("POST", "/budget/savings-goals", goalBody, testUserID)
	rr = execHandler(t, CreateSavingsGoal(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create goal: got %d: %s", rr.Code, rr.Body.String())
	}

	// 9. Complete onboarding
	completeBody := map[string]string{"step": "complete"}
	req = makeAuthRequest("PATCH", "/onboarding/step", completeBody, testUserID)
	rr = execHandler(t, UpdateOnboardingStep(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("complete: got %d: %s", rr.Code, rr.Body.String())
	}

	var finalStatus onboardingStatus
	json.NewDecoder(rr.Body).Decode(&finalStatus)
	if finalStatus.OnboardingStep == nil || *finalStatus.OnboardingStep != "complete" {
		t.Errorf("expected final step=complete, got %v", finalStatus.OnboardingStep)
	}
	if !finalStatus.HasIncomeStreams {
		t.Error("expected has_income_streams=true")
	}
	if !finalStatus.HasBudgetPeriod {
		t.Error("expected has_budget_period=true")
	}
	if !finalStatus.HasSavingsGoal {
		t.Error("expected has_savings_goal=true")
	}
}

// --- Savings Transaction → Goal Linking ---

func TestIntegration_SavingsTransactionDeductsFromGoal(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	periodID := seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)
	goalID := seedSavingsGoal(t, pool, testUserID, "Vacation Fund", 2000, false)
	seedCategoryMappings(t, pool)

	// Fill the goal with some money
	fillBody := map[string]any{
		"budget_period_id": periodID,
		"allocations":      []map[string]any{{"savings_goal_id": goalID, "amount": 500.0}},
	}
	req := makeAuthRequest("POST", "/budget/savings-goals/fill", fillBody, testUserID)
	rr := execHandler(t, FillSavingsGoals(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("fill: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Seed a transaction and override it to savings with goal
	food := "FOOD_AND_DRINK"
	txns := []testTxn{{Name: "TRAVEL EXPENSE", Amount: 200.00, Date: "2026-04-10", Category: &food}}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Get the transaction ID
	req = makeAuthRequest("GET", fmt.Sprintf("/budget/transactions?period_id=%s", periodID), nil, testUserID)
	rr = execHandler(t, ListTransactions(pool), req)
	var listResp struct {
		Transactions []struct {
			ID string `json:"id"`
		} `json:"transactions"`
	}
	json.NewDecoder(rr.Body).Decode(&listResp)
	txID := listResp.Transactions[0].ID

	// Override to savings with goal
	overrideBody := map[string]any{"budget_category": "savings", "savings_goal_id": goalID}
	req = makeAuthRequest("POST", "/budget/transactions/"+txID+"/override", overrideBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", txID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, OverrideTransactionCategory(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("override to savings: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify goal has spent and balance
	req = makeAuthRequest("GET", "/budget/savings-goals", nil, testUserID)
	rr = execHandler(t, ListSavingsGoals(pool), req)
	var goalsResp struct {
		SavingsGoals []struct {
			Spent   float64 `json:"spent"`
			Balance float64 `json:"balance"`
		} `json:"savings_goals"`
	}
	json.NewDecoder(rr.Body).Decode(&goalsResp)
	if len(goalsResp.SavingsGoals) == 0 {
		t.Fatal("expected at least one goal")
	}
	goal := goalsResp.SavingsGoals[0]
	if goal.Spent != 200 {
		t.Errorf("expected spent=200, got %v", goal.Spent)
	}
	if goal.Balance != 300 {
		t.Errorf("expected balance=300 (500 filled - 200 spent), got %v", goal.Balance)
	}
}

func TestIntegration_RecategorizeClearsGoalLink(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	periodID := seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)
	goalID := seedSavingsGoal(t, pool, testUserID, "Vacation Fund", 2000, false)
	seedCategoryMappings(t, pool)

	// Fill goal
	fillBody := map[string]any{
		"budget_period_id": periodID,
		"allocations":      []map[string]any{{"savings_goal_id": goalID, "amount": 500.0}},
	}
	req := makeAuthRequest("POST", "/budget/savings-goals/fill", fillBody, testUserID)
	execHandler(t, FillSavingsGoals(pool), req)

	// Seed and override to savings
	food := "FOOD_AND_DRINK"
	txns := []testTxn{{Name: "TRAVEL EXPENSE", Amount: 200.00, Date: "2026-04-10", Category: &food}}
	seedTransactions(t, pool, testUserID, accountID, txns)

	req = makeAuthRequest("GET", fmt.Sprintf("/budget/transactions?period_id=%s", periodID), nil, testUserID)
	rr := execHandler(t, ListTransactions(pool), req)
	var listResp struct {
		Transactions []struct{ ID string } `json:"transactions"`
	}
	json.NewDecoder(rr.Body).Decode(&listResp)
	txID := listResp.Transactions[0].ID

	// Override to savings
	overrideBody := map[string]any{"budget_category": "savings", "savings_goal_id": goalID}
	req = makeAuthRequest("POST", "/budget/transactions/"+txID+"/override", overrideBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", txID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	execHandler(t, OverrideTransactionCategory(pool), req)

	// Override back to flex — savings_goal_id should be cleared
	overrideBody = map[string]any{"budget_category": "flex"}
	req = makeAuthRequest("POST", "/budget/transactions/"+txID+"/override", overrideBody, testUserID)
	rctx = chi.NewRouteContext()
	rctx.URLParams.Add("id", txID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, OverrideTransactionCategory(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("override back to flex: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify goal balance is restored
	req = makeAuthRequest("GET", "/budget/savings-goals", nil, testUserID)
	rr = execHandler(t, ListSavingsGoals(pool), req)
	var goalsResp struct {
		SavingsGoals []struct {
			Spent   float64 `json:"spent"`
			Balance float64 `json:"balance"`
		} `json:"savings_goals"`
	}
	json.NewDecoder(rr.Body).Decode(&goalsResp)
	goal := goalsResp.SavingsGoals[0]
	if goal.Spent != 0 {
		t.Errorf("expected spent=0 after recategorize, got %v", goal.Spent)
	}
	if goal.Balance != 500 {
		t.Errorf("expected balance=500 after recategorize, got %v", goal.Balance)
	}
}

func TestIntegration_GoalCanGoNegative(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	periodID := seedBudgetPeriod(t, pool, testUserID, "2026-04-01", "2026-05-01", 5000)
	goalID := seedSavingsGoal(t, pool, testUserID, "Small Fund", 100, false)
	seedCategoryMappings(t, pool)

	// Fill with only 50
	fillBody := map[string]any{
		"budget_period_id": periodID,
		"allocations":      []map[string]any{{"savings_goal_id": goalID, "amount": 50.0}},
	}
	req := makeAuthRequest("POST", "/budget/savings-goals/fill", fillBody, testUserID)
	execHandler(t, FillSavingsGoals(pool), req)

	// Spend 200 from goal (more than current_amount)
	food := "FOOD_AND_DRINK"
	txns := []testTxn{{Name: "BIG EXPENSE", Amount: 200.00, Date: "2026-04-10", Category: &food}}
	seedTransactions(t, pool, testUserID, accountID, txns)

	req = makeAuthRequest("GET", fmt.Sprintf("/budget/transactions?period_id=%s", periodID), nil, testUserID)
	rr := execHandler(t, ListTransactions(pool), req)
	var listResp struct {
		Transactions []struct{ ID string } `json:"transactions"`
	}
	json.NewDecoder(rr.Body).Decode(&listResp)
	txID := listResp.Transactions[0].ID

	overrideBody := map[string]any{"budget_category": "savings", "savings_goal_id": goalID}
	req = makeAuthRequest("POST", "/budget/transactions/"+txID+"/override", overrideBody, testUserID)
	rctx := chi.NewRouteContext()
	rctx.URLParams.Add("id", txID)
	req = req.WithContext(withRouteContext(req.Context(), rctx))
	rr = execHandler(t, OverrideTransactionCategory(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("override: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}

	// Verify balance is negative
	req = makeAuthRequest("GET", "/budget/savings-goals", nil, testUserID)
	rr = execHandler(t, ListSavingsGoals(pool), req)
	var goalsResp struct {
		SavingsGoals []struct {
			Balance float64 `json:"balance"`
		} `json:"savings_goals"`
	}
	json.NewDecoder(rr.Body).Decode(&goalsResp)
	if goalsResp.SavingsGoals[0].Balance >= 0 {
		t.Errorf("expected negative balance, got %v", goalsResp.SavingsGoals[0].Balance)
	}
}

// --- Budget Period Rollover ---

func TestIntegration_SurplusRollover(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)

	// Period A: income -5000, expenses 3000 → surplus 2000
	seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 5000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 2000, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1000, Date: "2026-03-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Create Period B — carryover should be computed
	createBody := map[string]any{
		"start_date":     "2026-04-01",
		"end_date":       "2026-05-01",
		"income_target":  5000.0,
		"fixed_target":   2500.0,
		"flex_target":    1500.0,
		"savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		CarryoverAmount float64 `json:"carryover_amount"`
	}
	json.NewDecoder(rr.Body).Decode(&created)
	if created.CarryoverAmount != 2000 {
		t.Errorf("expected carryover=2000, got %v", created.CarryoverAmount)
	}
}

func TestIntegration_DeficitRollover(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)

	// Period A: income -3000, expenses 5000 → deficit -2000
	seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 3000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -3000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 3000, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 2000, Date: "2026-03-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Create Period B — carryover should be negative
	createBody := map[string]any{
		"start_date":     "2026-04-01",
		"end_date":       "2026-05-01",
		"income_target":  5000.0,
		"fixed_target":   2500.0,
		"flex_target":    1500.0,
		"savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		CarryoverAmount float64 `json:"carryover_amount"`
	}
	json.NewDecoder(rr.Body).Decode(&created)
	if created.CarryoverAmount != -2000 {
		t.Errorf("expected carryover=-2000, got %v", created.CarryoverAmount)
	}
}

func TestIntegration_ChainedRollover(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)

	// Period A: income -5000, expenses 3000 → surplus 2000
	seedBudgetPeriod(t, pool, testUserID, "2026-02-01", "2026-03-01", 5000)
	txnsA := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-02-15"},
		{Name: "RENT", Amount: 2000, Date: "2026-02-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1000, Date: "2026-02-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txnsA)

	// Period B: income -4000, expenses 4000 → surplus 0 + carryover 2000 from A
	createB := map[string]any{
		"start_date": "2026-03-01", "end_date": "2026-04-01",
		"income_target": 4000.0, "fixed_target": 2000.0, "flex_target": 1500.0, "savings_target": 500.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createB, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create B: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	txnsB := []testTxn{
		{Name: "PAYROLL", Amount: -4000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 2500, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1500, Date: "2026-03-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txnsB)

	// Period C: should have carryover = B's surplus (0) + B's carryover (2000) = 2000
	createC := map[string]any{
		"start_date": "2026-04-01", "end_date": "2026-05-01",
		"income_target": 5000.0, "fixed_target": 2500.0, "flex_target": 1500.0, "savings_target": 1000.0,
	}
	req = makeAuthRequest("POST", "/budget/periods", createC, testUserID)
	rr = execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create C: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		CarryoverAmount float64 `json:"carryover_amount"`
	}
	json.NewDecoder(rr.Body).Decode(&created)
	if created.CarryoverAmount != 2000 {
		t.Errorf("expected chained carryover=2000, got %v", created.CarryoverAmount)
	}
}

func TestIntegration_RolloverWithFills(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)
	goalID := seedSavingsGoal(t, pool, testUserID, "Emergency Fund", 10000, true)

	// Period A: income -5000, expenses 2000, fill 500 → surplus 2500
	periodA := seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 5000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 1000, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1000, Date: "2026-03-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Fill savings goal directly (past period, can't use FillSavingsGoals endpoint)
	seedAllocation(t, pool, testUserID, periodA, goalID, 500)

	// Create Period B — carryover should be 5000 - 2000 - 500 = 2500
	createBody := map[string]any{
		"start_date": "2026-04-01", "end_date": "2026-05-01",
		"income_target": 5000.0, "fixed_target": 2500.0, "flex_target": 1500.0, "savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}

	var created struct {
		CarryoverAmount float64 `json:"carryover_amount"`
	}
	json.NewDecoder(rr.Body).Decode(&created)
	if created.CarryoverAmount != 2500 {
		t.Errorf("expected carryover=2500, got %v", created.CarryoverAmount)
	}
}

// --- Withdraw from Savings ---

func TestIntegration_WithdrawFromSavings(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)
	goalID := seedSavingsGoal(t, pool, testUserID, "Emergency Fund", 10000, true)

	// Create a period with a deficit carryover
	seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 3000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -3000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 3000, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 2000, Date: "2026-03-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Fill goal directly (past period, can't use FillSavingsGoals endpoint)
	priorPeriodID := getPeriodID(t, pool, testUserID, "2026-03-01")
	seedAllocation(t, pool, testUserID, priorPeriodID, goalID, 1000)

	// Create current period — it will have negative carryover
	createBody := map[string]any{
		"start_date": "2026-04-01", "end_date": "2026-05-01",
		"income_target": 5000.0, "fixed_target": 2500.0, "flex_target": 1500.0, "savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	if rr.Code != http.StatusCreated {
		t.Fatalf("create: expected 201, got %d: %s", rr.Code, rr.Body.String())
	}
	var createdPeriod struct {
		ID              string  `json:"id"`
		CarryoverAmount float64 `json:"carryover_amount"`
	}
	json.NewDecoder(rr.Body).Decode(&createdPeriod)

	// Add income to current period so surplus calculation works
	txnsCurrent := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-04-15"},
		{Name: "RENT", Amount: 2500, Date: "2026-04-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1500, Date: "2026-04-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txnsCurrent)

	// Withdraw from savings to cover deficit
	withdrawBody := map[string]any{
		"budget_period_id": createdPeriod.ID,
		"withdrawals":      []map[string]any{{"savings_goal_id": goalID, "amount": 500.0}},
	}
	req = makeAuthRequest("POST", "/budget/savings-goals/withdraw", withdrawBody, testUserID)
	rr = execHandler(t, WithdrawSavingsGoals(pool), req)
	if rr.Code != http.StatusOK {
		t.Fatalf("withdraw: expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_WithdrawExceedsDeficit(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)
	goalID := seedSavingsGoal(t, pool, testUserID, "Emergency Fund", 10000, true)

	// Create a period with small deficit
	seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 3000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -3000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 3500, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	priorPeriodID := getPeriodID(t, pool, testUserID, "2026-03-01")
	seedAllocation(t, pool, testUserID, priorPeriodID, goalID, 5000)

	createBody := map[string]any{
		"start_date": "2026-04-01", "end_date": "2026-05-01",
		"income_target": 5000.0, "fixed_target": 2500.0, "flex_target": 1500.0, "savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	var createdPeriod struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&createdPeriod)

	// Add some income but keep deficit via carryover
	txnsCurrent := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-04-15"},
		{Name: "RENT", Amount: 2500, Date: "2026-04-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1500, Date: "2026-04-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txnsCurrent)

	// Try to withdraw more than the deficit
	withdrawBody := map[string]any{
		"budget_period_id": createdPeriod.ID,
		"withdrawals":      []map[string]any{{"savings_goal_id": goalID, "amount": 99999.0}},
	}
	req = makeAuthRequest("POST", "/budget/savings-goals/withdraw", withdrawBody, testUserID)
	rr = execHandler(t, WithdrawSavingsGoals(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for withdrawal exceeding deficit, got %d: %s", rr.Code, rr.Body.String())
	}
}

func TestIntegration_WithdrawExceedsGoalBalance(t *testing.T) {
	pool := setupTestDB(t)
	seedUser(t, pool, testUserID)
	accountID := seedAccount(t, pool, testUserID)
	seedCategoryMappings(t, pool)
	goalID := seedSavingsGoal(t, pool, testUserID, "Small Fund", 100, false)

	// Create deficit period
	seedBudgetPeriod(t, pool, testUserID, "2026-03-01", "2026-04-01", 3000)
	txns := []testTxn{
		{Name: "PAYROLL", Amount: -3000, Date: "2026-03-15"},
		{Name: "RENT", Amount: 5000, Date: "2026-03-01", Category: strPtr("RENT_AND_UTILITIES")},
	}
	seedTransactions(t, pool, testUserID, accountID, txns)

	// Fill goal with only 50 (past period, seed directly)
	priorPeriodID := getPeriodID(t, pool, testUserID, "2026-03-01")
	seedAllocation(t, pool, testUserID, priorPeriodID, goalID, 50)

	createBody := map[string]any{
		"start_date": "2026-04-01", "end_date": "2026-05-01",
		"income_target": 5000.0, "fixed_target": 2500.0, "flex_target": 1500.0, "savings_target": 1000.0,
	}
	req := makeAuthRequest("POST", "/budget/periods", createBody, testUserID)
	rr := execHandler(t, CreatePeriod(pool), req)
	var createdPeriod struct {
		ID string `json:"id"`
	}
	json.NewDecoder(rr.Body).Decode(&createdPeriod)

	// Current period also has deficit via carryover
	txnsCurrent := []testTxn{
		{Name: "PAYROLL", Amount: -5000, Date: "2026-04-15"},
		{Name: "RENT", Amount: 2500, Date: "2026-04-01", Category: strPtr("RENT_AND_UTILITIES")},
		{Name: "FOOD", Amount: 1500, Date: "2026-04-05", Category: strPtr("FOOD_AND_DRINK")},
	}
	seedTransactions(t, pool, testUserID, accountID, txnsCurrent)

	// Try to withdraw 100 when goal balance is only 50
	withdrawBody := map[string]any{
		"budget_period_id": createdPeriod.ID,
		"withdrawals":      []map[string]any{{"savings_goal_id": goalID, "amount": 100.0}},
	}
	req = makeAuthRequest("POST", "/budget/savings-goals/withdraw", withdrawBody, testUserID)
	rr = execHandler(t, WithdrawSavingsGoals(pool), req)
	if rr.Code != http.StatusBadRequest {
		t.Errorf("expected 400 for withdrawal exceeding goal balance, got %d: %s", rr.Code, rr.Body.String())
	}
}
