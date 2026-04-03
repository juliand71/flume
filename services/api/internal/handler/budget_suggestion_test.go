package handler

import (
	"testing"
	"time"
)

func TestComputeSuggestionDates(t *testing.T) {
	d := func(s string) time.Time {
		t, _ := time.Parse("2006-01-02", s)
		return t
	}
	sp := func(s string) *string { return &s }

	tests := []struct {
		name            string
		today           time.Time
		frequency       string
		nextExpectedDate *string
		wantStart       string
		wantEnd         string
	}{
		{
			name:      "monthly",
			today:     d("2026-04-15"),
			frequency: "monthly",
			wantStart: "2026-04-01",
			wantEnd:   "2026-05-01",
		},
		{
			name:            "biweekly with next expected",
			today:           d("2026-04-15"),
			frequency:       "biweekly",
			nextExpectedDate: sp("2026-04-20"),
			wantStart:       "2026-04-06",
			wantEnd:         "2026-04-20",
		},
		{
			name:      "biweekly no next expected",
			today:     d("2026-04-15"),
			frequency: "biweekly",
			wantStart: "2026-04-15",
			wantEnd:   "2026-04-29",
		},
		{
			name:      "semimonthly first half",
			today:     d("2026-04-10"),
			frequency: "semimonthly",
			wantStart: "2026-04-01",
			wantEnd:   "2026-04-16",
		},
		{
			name:      "semimonthly second half",
			today:     d("2026-04-20"),
			frequency: "semimonthly",
			wantStart: "2026-04-16",
			wantEnd:   "2026-05-01",
		},
		{
			name:            "weekly with next expected",
			today:           d("2026-04-15"),
			frequency:       "weekly",
			nextExpectedDate: sp("2026-04-18"),
			wantStart:       "2026-04-11",
			wantEnd:         "2026-04-18",
		},
		{
			name:      "unknown frequency falls back to monthly",
			today:     d("2026-04-15"),
			frequency: "garbage",
			wantStart: "2026-04-01",
			wantEnd:   "2026-05-01",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			start, end := computeSuggestionDates(tt.today, tt.frequency, tt.nextExpectedDate)
			gotStart := start.Format("2006-01-02")
			gotEnd := end.Format("2006-01-02")
			if gotStart != tt.wantStart {
				t.Errorf("start = %s, want %s", gotStart, tt.wantStart)
			}
			if gotEnd != tt.wantEnd {
				t.Errorf("end = %s, want %s", gotEnd, tt.wantEnd)
			}
		})
	}
}

func TestComputeBudgetSplit(t *testing.T) {
	tests := []struct {
		income      float64
		wantFixed   float64
		wantFlex    float64
		wantSavings float64
	}{
		{5000, 2500, 1500, 1000},
		{0, 0, 0, 0},
		{100.01, 50.01, 30.00, 20.00},
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			fixed, flex, savings := computeBudgetSplit(tt.income)
			if fixed != tt.wantFixed {
				t.Errorf("fixed = %v, want %v", fixed, tt.wantFixed)
			}
			if flex != tt.wantFlex {
				t.Errorf("flex = %v, want %v", flex, tt.wantFlex)
			}
			if savings != tt.wantSavings {
				t.Errorf("savings = %v, want %v", savings, tt.wantSavings)
			}
		})
	}
}
