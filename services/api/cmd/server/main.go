package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	"github.com/julianwachholz/flume/services/api/internal/auth"
	"github.com/julianwachholz/flume/services/api/internal/db"
	"github.com/julianwachholz/flume/services/api/internal/handler"
)

func main() {
	dbURL := os.Getenv("SUPABASE_DB_URL")
	if dbURL == "" {
		log.Fatal("SUPABASE_DB_URL is required")
	}

	supabaseURL := os.Getenv("SUPABASE_URL")
	if supabaseURL == "" {
		log.Fatal("SUPABASE_URL is required")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "3002"
	}

	ctx := context.Background()

	pool, err := db.NewPool(ctx, dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer pool.Close()

	keys, err := auth.FetchPublicKeys(supabaseURL)
	if err != nil {
		log.Fatalf("Failed to fetch JWKS: %v", err)
	}
	log.Printf("Loaded %d JWT public key(s)", len(keys))

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)

	// Public routes
	r.Get("/health", handler.Health(pool))

	// Authenticated routes
	r.Group(func(r chi.Router) {
		r.Use(auth.Middleware(keys))
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
		r.Patch("/budget/periods/{id}", handler.UpdatePeriod(pool))

		// Category summary
		r.Get("/budget/category-summary", handler.GetCategorySummary(pool))

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
