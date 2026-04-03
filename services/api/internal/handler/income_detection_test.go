package handler

import (
	"math"
	"testing"
)

func TestNormalizeTxnName(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{"ACME CORP PAYROLL", "acme corp payroll"},
		{"SHELL OIL #4412", "shell oil #"},
		{"  lots   of   spaces  ", "lots of spaces"},
		{"PAYMENT 12", "payment 12"},
		{"PAYMENT 123", "payment"},
		{"", ""},
		{"ALREADY lowercase", "already lowercase"},
		{"TRAILING 99999", "trailing"},
	}

	for _, tt := range tests {
		t.Run(tt.input, func(t *testing.T) {
			got := normalizeTxnName(tt.input)
			if got != tt.expected {
				t.Errorf("normalizeTxnName(%q) = %q, want %q", tt.input, got, tt.expected)
			}
		})
	}
}

func TestClassifyFrequency(t *testing.T) {
	tests := []struct {
		medianDays int
		expected   string
	}{
		{4, ""},
		{5, "weekly"},
		{7, "weekly"},
		{9, "weekly"},
		{10, ""},
		{11, ""},
		{12, "biweekly"},
		{14, "biweekly"},
		{16, "biweekly"},
		{17, ""},
		{26, ""},
		{27, "monthly"},
		{30, "monthly"},
		{33, "monthly"},
		{34, ""},
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			got := classifyFrequency(tt.medianDays)
			if got != tt.expected {
				t.Errorf("classifyFrequency(%d) = %q, want %q", tt.medianDays, got, tt.expected)
			}
		})
	}
}

func TestComputePeriodAmount(t *testing.T) {
	tests := []struct {
		amount     float64
		frequency  string
		periodDays int
		expected   float64
	}{
		{2800, "biweekly", 14, 2800},
		{2800, "biweekly", 28, 5600},
		{5000, "monthly", 30, 5000},
		{1000, "weekly", 14, 2000},
		{3000, "semimonthly", 30, 6000},
		{2800, "biweekly", 1, 2800}, // clamped to 1 occurrence
	}

	for _, tt := range tests {
		t.Run("", func(t *testing.T) {
			got := computePeriodAmount(tt.amount, tt.frequency, tt.periodDays)
			if got != tt.expected {
				t.Errorf("computePeriodAmount(%v, %q, %d) = %v, want %v",
					tt.amount, tt.frequency, tt.periodDays, got, tt.expected)
			}
		})
	}
}

func TestMedianInt(t *testing.T) {
	tests := []struct {
		name     string
		vals     []int
		expected int
	}{
		{"empty", []int{}, 0},
		{"single", []int{7}, 7},
		{"odd length", []int{3, 1, 2}, 2},
		{"even length", []int{1, 2, 3, 4}, 2}, // (2+3)/2 = 2 (integer division)
		{"unsorted", []int{14, 7, 14, 13}, 13}, // sorts to [7,13,14,14] → (13+14)/2 = 13
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := medianInt(tt.vals)
			if got != tt.expected {
				t.Errorf("medianInt(%v) = %d, want %d", tt.vals, got, tt.expected)
			}
		})
	}
}

func TestMedianFloat(t *testing.T) {
	// NOTE: medianFloat does NOT sort internally — caller must pre-sort
	tests := []struct {
		name     string
		vals     []float64
		expected float64
	}{
		{"empty", []float64{}, 0},
		{"single", []float64{42.5}, 42.5},
		{"odd sorted", []float64{1.0, 2.0, 3.0}, 2.0},
		{"even sorted", []float64{1.0, 2.0, 3.0, 4.0}, 2.5},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := medianFloat(tt.vals)
			if got != tt.expected {
				t.Errorf("medianFloat(%v) = %v, want %v", tt.vals, got, tt.expected)
			}
		})
	}
}

func TestStddevInt(t *testing.T) {
	tests := []struct {
		name     string
		vals     []int
		expected float64
	}{
		{"empty", []int{}, 0},
		{"single", []int{5}, 0},
		{"identical", []int{7, 7, 7}, 0},
		{"varied", []int{14, 14, 15, 13}, 0.7071067811865476},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := stddevInt(tt.vals)
			if math.Abs(got-tt.expected) > 0.0001 {
				t.Errorf("stddevInt(%v) = %v, want %v", tt.vals, got, tt.expected)
			}
		})
	}
}
