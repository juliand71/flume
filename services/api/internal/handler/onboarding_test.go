package handler

import "testing"

func TestStepIndex(t *testing.T) {
	expected := map[string]int{
		"welcome":        0,
		"link_bank":      1,
		"syncing":        2,
		"choose_period":  3,
		"confirm_income": 4,
		"confirm_fixed":  5,
		"confirm_flex":   6,
		"review_savings": 7,
		"savings_goal":   8,
		"complete":       9,
	}

	for step, want := range expected {
		t.Run(step, func(t *testing.T) {
			got := stepIndex(step)
			if got != want {
				t.Errorf("stepIndex(%q) = %d, want %d", step, got, want)
			}
		})
	}

	t.Run("invalid step", func(t *testing.T) {
		if got := stepIndex("nonexistent"); got != -1 {
			t.Errorf("stepIndex(\"nonexistent\") = %d, want -1", got)
		}
	})

	t.Run("ordering is strictly increasing", func(t *testing.T) {
		for i := 1; i < len(onboardingStepOrder); i++ {
			prev := stepIndex(onboardingStepOrder[i-1])
			curr := stepIndex(onboardingStepOrder[i])
			if curr <= prev {
				t.Errorf("step %q (index %d) should be > step %q (index %d)",
					onboardingStepOrder[i], curr, onboardingStepOrder[i-1], prev)
			}
		}
	})
}
