package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/joho/godotenv"
	"github.com/juliand71/flume/services/api/internal/auth"
	"github.com/juliand71/flume/services/api/internal/db"
	"github.com/juliand71/flume/services/api/internal/docs"
	"github.com/juliand71/flume/services/api/internal/handler"
)

func main() {
	godotenv.Load()

	debugMode := flag.Bool("debug", os.Getenv("DEBUG") == "1", "enable debug mode (Swagger UI, auth bypass)")
	realAuth := flag.Bool("real-auth", false, "use real JWT auth even in debug mode")
	portFlag := flag.String("port", "", "override PORT env var")
	flag.Parse()

	dbURL := os.Getenv("SUPABASE_DB_URL")
	if dbURL == "" {
		log.Fatal("SUPABASE_DB_URL is required")
	}

	supabaseURL := os.Getenv("SUPABASE_URL")

	port := os.Getenv("PORT")
	if port == "" {
		port = "3002"
	}
	if *portFlag != "" {
		port = *portFlag
	}

	ctx := context.Background()

	pool, err := db.NewPool(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	// Select auth middleware
	var authMiddleware func(http.Handler) http.Handler
	if *debugMode && !*realAuth {
		log.Println("*** DEBUG MODE: Auth bypassed, using debug user ID ***")
		authMiddleware = auth.DebugMiddleware()
	} else {
		if supabaseURL == "" {
			log.Fatal("SUPABASE_URL is required")
		}
		keys, err := auth.FetchPublicKeys(supabaseURL)
		if err != nil {
			log.Fatalf("Failed to fetch JWKS: %v", err)
		}
		log.Printf("Loaded %d JWT public key(s)", len(keys))
		authMiddleware = auth.Middleware(keys)
	}

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Public routes
	r.Get("/health", handler.Health(pool))

	// Swagger UI + debug-only routes
	if *debugMode {
		r.Mount("/docs", docs.Routes())
		log.Printf("Swagger UI available at http://localhost:%s/docs", port)

		// Debug-only transaction endpoints (behind auth so X-Debug-User-ID works)
		r.Group(func(r chi.Router) {
			r.Use(authMiddleware)
			r.Post("/debug/transactions", handler.CreateDebugTransaction(pool))
			r.Delete("/debug/transactions", handler.DeleteDebugTransactions(pool))
		})
	}

	// Authenticated routes
	r.Group(func(r chi.Router) {
		r.Use(authMiddleware)

		// Onboarding
		r.Get("/onboarding/status", handler.GetOnboardingStatus(pool))
		r.Patch("/onboarding/step", handler.UpdateOnboardingStep(pool))

		r.Get("/budget/accounts", handler.ListAccounts(pool))
		r.Patch("/budget/accounts/{id}/role", handler.UpdateAccountRole(pool))

		// Income streams
		r.Get("/budget/income-streams", handler.ListIncomeStreams(pool))
		r.Post("/budget/income-streams", handler.CreateIncomeStream(pool))
		r.Patch("/budget/income-streams/{id}", handler.UpdateIncomeStream(pool))
		r.Delete("/budget/income-streams/{id}", handler.DeleteIncomeStream(pool))

		// Budget periods
		r.Get("/budget/current-period", handler.GetCurrentPeriod(pool))
		r.Get("/budget/periods", handler.ListPeriods(pool))
		r.Post("/budget/periods", handler.CreatePeriod(pool))
		r.Get("/budget/periods/{id}", handler.GetPeriodByID(pool))
		r.Patch("/budget/periods/{id}", handler.UpdatePeriod(pool))
		r.Get("/budget/periods/{id}/allocations", handler.ListPeriodAllocations(pool))

		// Category summary
		r.Get("/budget/category-summary", handler.GetCategorySummary(pool))

		// Sync status + detection + budget suggestion (onboarding)
		r.Get("/budget/sync-status", handler.GetSyncStatus(pool))
		r.Get("/budget/detect-income", handler.DetectIncome(pool))
		r.Get("/budget/detect-fixed", handler.DetectFixed(pool))
		r.Get("/budget/detect-flex", handler.DetectFlex(pool))
		r.Post("/budget/suggest-period", handler.SuggestPeriod(pool))

		// Transactions
		r.Get("/budget/transactions", handler.ListTransactions(pool))
		r.Post("/budget/transactions/{id}/override", handler.OverrideTransactionCategory(pool))

		// Category mappings
		r.Get("/budget/categories", handler.ListCategoryMappings(pool))
		r.Post("/budget/categories", handler.CreateCategoryMapping(pool))

		// Savings goals
		r.Get("/budget/savings-goals", handler.ListSavingsGoals(pool))
		r.Post("/budget/savings-goals", handler.CreateSavingsGoal(pool))
		r.Post("/budget/savings-goals/fill", handler.FillSavingsGoals(pool))
		r.Patch("/budget/savings-goals/{id}", handler.UpdateSavingsGoal(pool))
		r.Delete("/budget/savings-goals/{id}", handler.DeleteSavingsGoal(pool))
	})

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	// Graceful shutdown
	go func() {
		sigCh := make(chan os.Signal, 1)
		signal.Notify(sigCh, syscall.SIGTERM, syscall.SIGINT)
		<-sigCh

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("HTTP server shutdown error: %v", err)
		}
	}()

	log.Printf("API server listening on :%s", port)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("HTTP server error: %v", err)
	}
}
