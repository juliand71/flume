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

type detectedStream struct {
	Name             string  `json:"name"`
	EstimatedAmount  float64 `json:"estimated_amount"`
	Frequency        string  `json:"frequency"`
	NextExpectedDate *string `json:"next_expected_date"`
	Occurrences      int     `json:"occurrences"`
	Confidence       string  `json:"confidence"`
}

type incomeDetectionResponse struct {
	DetectedStreams       []detectedStream `json:"detected_streams"`
	MonthlyExpenseEstimate float64         `json:"monthly_expense_estimate"`
	TransactionCount      int              `json:"transaction_count"`
	DateRangeDays         int              `json:"date_range_days"`
}

func DetectIncome(pool *pgxpool.Pool) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		userID := auth.UserID(r.Context())

		// 1. Fetch income transactions (amount < 0 in Plaid convention)
		rows, err := pool.Query(r.Context(), `
			SELECT name, amount, date::text
			FROM transactions
			WHERE user_id = $1
			  AND personal_finance_category->>'primary' = 'INCOME'
			  AND amount < 0
			ORDER BY name, date
		`, userID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "failed to query income transactions")
			return
		}
		defer rows.Close()

		type txn struct {
			name   string
			amount float64
			date   string
		}

		// Group by normalized name
		groups := map[string][]txn{}
		for rows.Next() {
			var t txn
			if err := rows.Scan(&t.name, &t.amount, &t.date); err != nil {
				writeError(w, http.StatusInternalServerError, "failed to scan transaction")
				return
			}
			key := normalizeTxnName(t.name)
			groups[key] = append(groups[key], t)
		}

		// 2. Detect patterns in each group
		var detected []detectedStream
		for _, txns := range groups {
			if len(txns) < 2 {
				continue
			}

			// Parse dates and compute intervals
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

			// Sort dates chronologically
			sort.Slice(dates, func(i, j int) bool { return dates[i].Before(dates[j]) })

			// Compute intervals between consecutive dates
			var intervals []int
			for i := 1; i < len(dates); i++ {
				days := int(dates[i].Sub(dates[i-1]).Hours() / 24)
				intervals = append(intervals, days)
			}

			// Classify frequency by median interval
			medianInterval := medianInt(intervals)
			freq := classifyFrequency(medianInterval)
			if freq == "" {
				continue
			}

			// Compute estimated amount (median of absolute amounts)
			sort.Float64s(amounts)
			estAmount := medianFloat(amounts)

			// Compute next expected date
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
				// If last was around 1st, next is around 15th, and vice versa
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

			// Assess confidence
			stddev := stddevInt(intervals)
			confidence := "low"
			if len(txns) >= 4 && stddev < 3.0 {
				confidence = "high"
			} else if len(txns) >= 2 && stddev < 5.0 {
				confidence = "medium"
			}

			// Use the original (non-normalized) name from the most recent transaction
			displayName := txns[len(txns)-1].name

			detected = append(detected, detectedStream{
				Name:             displayName,
				EstimatedAmount:  math.Round(estAmount*100) / 100,
				Frequency:        freq,
				NextExpectedDate: nextDate,
				Occurrences:      len(txns),
				Confidence:       confidence,
			})
		}

		// Sort by estimated amount descending
		sort.Slice(detected, func(i, j int) bool {
			return detected[i].EstimatedAmount > detected[j].EstimatedAmount
		})

		// 3. Compute monthly expense estimate and date range
		var totalExpenses float64
		var minDate, maxDate *string
		var txnCount int

		err = pool.QueryRow(r.Context(), `
			SELECT
				COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as total_expenses,
				MIN(date)::text as min_date,
				MAX(date)::text as max_date,
				COUNT(*) as txn_count
			FROM transactions
			WHERE user_id = $1
		`, userID).Scan(&totalExpenses, &minDate, &maxDate, &txnCount)
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
		}
		if resp.DetectedStreams == nil {
			resp.DetectedStreams = []detectedStream{}
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}
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
