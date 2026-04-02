package handler

import (
	"encoding/json"
	"math"
	"net/http"
	"regexp"
	"sort"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/julianwachholz/flume/services/api/internal/auth"
)

var trailingDigitsRe = regexp.MustCompile(`\s*\d{3,}$`)
var extraSpacesRe = regexp.MustCompile(`\s+`)

func normalizeTxnName(name string) string {
	s := strings.ToLower(strings.TrimSpace(name))
	s = trailingDigitsRe.ReplaceAllString(s, "")
	s = extraSpacesRe.ReplaceAllString(s, " ")
	return strings.TrimSpace(s)
}

type streamTransaction struct {
	Date   string  `json:"date"`
	Amount float64 `json:"amount"`
	Name   string  `json:"name"`
}

type detectedStream struct {
	Name             string              `json:"name"`
	EstimatedAmount  float64             `json:"estimated_amount"`
	TotalAmount      float64             `json:"total_amount"`
	PeriodAmount     float64             `json:"period_amount"`
	Frequency        string              `json:"frequency"`
	NextExpectedDate *string             `json:"next_expected_date"`
	Occurrences      int                 `json:"occurrences"`
	Confidence       string              `json:"confidence"`
	Transactions     []streamTransaction `json:"transactions"`
}

type incomeDetectionResponse struct {
	DetectedStreams        []detectedStream `json:"detected_streams"`
	MonthlyExpenseEstimate float64          `json:"monthly_expense_estimate"`
	TransactionCount      int              `json:"transaction_count"`
	DateRangeDays         int              `json:"date_range_days"`
	ExpandedSearch        bool             `json:"expanded_search"`
}

func computePeriodAmount(estimatedAmount float64, frequency string, periodDays int) float64 {
	var intervalDays float64
	switch frequency {
	case "weekly":
		intervalDays = 7
	case "biweekly":
		intervalDays = 14
	case "semimonthly":
		intervalDays = 15.2
	case "monthly":
		intervalDays = 30.4
	default:
		intervalDays = 30.4
	}
	occurrences := math.Round(float64(periodDays) / intervalDays)
	if occurrences < 1 {
		occurrences = 1
	}
	return math.Round(estimatedAmount*occurrences*100) / 100
}

func DetectIncome(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		// Parse optional date range params
		startDateStr := r.URL.Query().Get("start_date")
		endDateStr := r.URL.Query().Get("end_date")
		var startDate, endDate *time.Time
		if startDateStr != "" {
			if d, err := time.Parse("2006-01-02", startDateStr); err == nil {
				startDate = &d
			}
		}
		if endDateStr != "" {
			if d, err := time.Parse("2006-01-02", endDateStr); err == nil {
				endDate = &d
			}
		}

		// Compute period length for per-period income scaling
		periodDays := 0
		if startDate != nil && endDate != nil {
			periodDays = int(endDate.Sub(*startDate).Hours()/24) + 1
		}

		detected, err := queryIncomeStreams(r, pool, userID, startDate, endDate)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to detect income")
			return
		}

		// Fallback: if date-scoped query returned nothing, expand to all history
		expandedSearch := false
		if len(detected) == 0 && startDate != nil {
			detected, err = queryIncomeStreams(r, pool, userID, nil, nil)
			if err != nil {
				writeError(w, http.StatusInternalServerError, "failed to detect income")
				return
			}
			if len(detected) > 0 {
				expandedSearch = true
			}
		}

		// Set period amount on each detected stream
		if periodDays > 0 {
			for i := range detected {
				detected[i].PeriodAmount = computePeriodAmount(detected[i].EstimatedAmount, detected[i].Frequency, periodDays)
			}
		}

		// Compute expense estimate and date range
		var totalExpenses float64
		var minDate, maxDate *string
		var txnCount int

		if startDate != nil && endDate != nil {
			err = pool.QueryRow(r.Context(), `
				SELECT
					COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as total_expenses,
					MIN(date)::text as min_date,
					MAX(date)::text as max_date,
					COUNT(*) as txn_count
				FROM transactions
				WHERE user_id = $1 AND date >= $2 AND date < $3
			`, userID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02")).Scan(&totalExpenses, &minDate, &maxDate, &txnCount)
		} else {
			err = pool.QueryRow(r.Context(), `
				SELECT
					COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as total_expenses,
					MIN(date)::text as min_date,
					MAX(date)::text as max_date,
					COUNT(*) as txn_count
				FROM transactions
				WHERE user_id = $1
			`, userID).Scan(&totalExpenses, &minDate, &maxDate, &txnCount)
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to compute expense estimate")
			return
		}

		dateRangeDays := 0
		monthlyExpense := 0.0
		if minDate != nil && maxDate != nil {
			mn, _ := time.Parse("2006-01-02", *minDate)
			mx, _ := time.Parse("2006-01-02", *maxDate)
			dateRangeDays = int(mx.Sub(mn).Hours()/24) + 1
			if dateRangeDays > 0 {
				months := float64(dateRangeDays) / 30.0
				if months > 0 {
					monthlyExpense = math.Round(totalExpenses/months*100) / 100
				}
			}
		}

		resp := incomeDetectionResponse{
			DetectedStreams:        detected,
			MonthlyExpenseEstimate: monthlyExpense,
			TransactionCount:      txnCount,
			DateRangeDays:         dateRangeDays,
			ExpandedSearch:        expandedSearch,
		}
		if resp.DetectedStreams == nil {
			resp.DetectedStreams = []detectedStream{}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
}

func queryIncomeStreams(r *http.Request, pool *pgxpool.Pool, userID string, startDate, endDate *time.Time) ([]detectedStream, error) {
	var query string
	var args []any

	if startDate != nil && endDate != nil {
		query = `
			SELECT t.name, t.amount, t.date::text
			FROM transactions t
			WHERE t.user_id = $1
			  AND t.amount < 0
			  AND (
			    t.personal_finance_category IS NULL
			    OR t.personal_finance_category->>'primary' NOT IN (
			      'LOAN_PAYMENTS', 'TRANSFER_OUT', 'BANK_FEES'
			    )
			  )
			  AND NOT (
			    t.personal_finance_category->>'primary' = 'TRANSFER_IN'
			    AND t.personal_finance_category->>'detailed' IN (
			      'TRANSFER_IN_ACCOUNT_TRANSFER', 'TRANSFER_IN_SAVINGS'
			    )
			  )
			  AND NOT EXISTS (
			    SELECT 1 FROM transactions t2
			    WHERE t2.user_id = t.user_id
			      AND t2.account_id != t.account_id
			      AND t2.amount = -t.amount
			      AND t2.date BETWEEN t.date - 1 AND t.date + 1
			  )
			  AND t.date >= $2 AND t.date < $3
			ORDER BY t.name, t.date
		`
		args = []any{userID, startDate.Format("2006-01-02"), endDate.Format("2006-01-02")}
	} else {
		query = `
			SELECT t.name, t.amount, t.date::text
			FROM transactions t
			WHERE t.user_id = $1
			  AND t.amount < 0
			  AND (
			    t.personal_finance_category IS NULL
			    OR t.personal_finance_category->>'primary' NOT IN (
			      'LOAN_PAYMENTS', 'TRANSFER_OUT', 'BANK_FEES'
			    )
			  )
			  AND NOT (
			    t.personal_finance_category->>'primary' = 'TRANSFER_IN'
			    AND t.personal_finance_category->>'detailed' IN (
			      'TRANSFER_IN_ACCOUNT_TRANSFER', 'TRANSFER_IN_SAVINGS'
			    )
			  )
			  AND NOT EXISTS (
			    SELECT 1 FROM transactions t2
			    WHERE t2.user_id = t.user_id
			      AND t2.account_id != t.account_id
			      AND t2.amount = -t.amount
			      AND t2.date BETWEEN t.date - 1 AND t.date + 1
			  )
			ORDER BY t.name, t.date
		`
		args = []any{userID}
	}

	rows, err := pool.Query(r.Context(), query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	type txn struct {
		name   string
		amount float64
		date   string
	}

	groups := map[string][]txn{}
	for rows.Next() {
		var t txn
		if err := rows.Scan(&t.name, &t.amount, &t.date); err != nil {
			return nil, err
		}
		key := normalizeTxnName(t.name)
		groups[key] = append(groups[key], t)
	}

	var detected []detectedStream
	for _, txns := range groups {
		if len(txns) < 2 {
			continue
		}

		var dates []time.Time
		var amounts []float64
		for _, t := range txns {
			d, err := time.Parse("2006-01-02", t.date)
			if err != nil {
				continue
			}
			dates = append(dates, d)
			amounts = append(amounts, math.Abs(t.amount))
		}
		if len(dates) < 2 {
			continue
		}

		sort.Slice(dates, func(i, j int) bool { return dates[i].Before(dates[j]) })

		var intervals []int
		for i := 1; i < len(dates); i++ {
			days := int(dates[i].Sub(dates[i-1]).Hours() / 24)
			intervals = append(intervals, days)
		}

		medianInterval := medianInt(intervals)
		freq := classifyFrequency(medianInterval)
		if freq == "" {
			continue
		}

		sort.Float64s(amounts)
		estAmount := medianFloat(amounts)

		lastDate := dates[len(dates)-1]
		var nextDate *string
		switch freq {
		case "weekly":
			nd := lastDate.AddDate(0, 0, 7)
			s := nd.Format("2006-01-02")
			nextDate = &s
		case "biweekly":
			nd := lastDate.AddDate(0, 0, 14)
			s := nd.Format("2006-01-02")
			nextDate = &s
		case "monthly":
			nd := lastDate.AddDate(0, 1, 0)
			s := nd.Format("2006-01-02")
			nextDate = &s
		case "semimonthly":
			if lastDate.Day() <= 15 {
				nd := time.Date(lastDate.Year(), lastDate.Month(), 15, 0, 0, 0, 0, time.UTC)
				s := nd.Format("2006-01-02")
				nextDate = &s
			} else {
				nd := time.Date(lastDate.Year(), lastDate.Month()+1, 1, 0, 0, 0, 0, time.UTC)
				s := nd.Format("2006-01-02")
				nextDate = &s
			}
		}

		stddev := stddevInt(intervals)
		confidence := "low"
		if len(txns) >= 4 && stddev < 3.0 {
			confidence = "high"
		} else if len(txns) >= 2 && stddev < 5.0 {
			confidence = "medium"
		}

		displayName := txns[len(txns)-1].name

		var totalAmount float64
		var streamTxns []streamTransaction
		for _, t := range txns {
			absAmt := math.Abs(t.amount)
			totalAmount += absAmt
			streamTxns = append(streamTxns, streamTransaction{
				Date:   t.date,
				Amount: math.Round(absAmt*100) / 100,
				Name:   t.name,
			})
		}

		detected = append(detected, detectedStream{
			Name:             displayName,
			EstimatedAmount:  math.Round(estAmount*100) / 100,
			TotalAmount:      math.Round(totalAmount*100) / 100,
			Frequency:        freq,
			NextExpectedDate: nextDate,
			Occurrences:      len(txns),
			Confidence:       confidence,
			Transactions:     streamTxns,
		})
	}

	sort.Slice(detected, func(i, j int) bool {
		return detected[i].EstimatedAmount > detected[j].EstimatedAmount
	})

	return detected, nil
}

func classifyFrequency(medianDays int) string {
	switch {
	case medianDays >= 5 && medianDays <= 9:
		return "weekly"
	case medianDays >= 12 && medianDays <= 16:
		return "biweekly"
	case medianDays >= 27 && medianDays <= 33:
		return "monthly"
	default:
		return ""
	}
}

func medianInt(vals []int) int {
	if len(vals) == 0 {
		return 0
	}
	sorted := make([]int, len(vals))
	copy(sorted, vals)
	sort.Ints(sorted)
	mid := len(sorted) / 2
	if len(sorted)%2 == 0 {
		return (sorted[mid-1] + sorted[mid]) / 2
	}
	return sorted[mid]
}

func medianFloat(vals []float64) float64 {
	if len(vals) == 0 {
		return 0
	}
	mid := len(vals) / 2
	if len(vals)%2 == 0 {
		return (vals[mid-1] + vals[mid]) / 2
	}
	return vals[mid]
}

func stddevInt(vals []int) float64 {
	if len(vals) == 0 {
		return 0
	}
	sum := 0.0
	for _, v := range vals {
		sum += float64(v)
	}
	mean := sum / float64(len(vals))
	variance := 0.0
	for _, v := range vals {
		d := float64(v) - mean
		variance += d * d
	}
	variance /= float64(len(vals))
	return math.Sqrt(variance)
}
