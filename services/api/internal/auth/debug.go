package auth

import (
	"context"
	"net/http"
)

const DebugUserID = "00000000-0000-0000-0000-000000000000"

// DebugMiddleware bypasses JWT validation and injects a fixed debug user ID.
// Use X-Debug-User-ID header to override the user ID for multi-user testing.
func DebugMiddleware() func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			userID := DebugUserID
			if override := r.Header.Get("X-Debug-User-ID"); override != "" {
				userID = override
			}
			ctx := context.WithValue(r.Context(), UserIDKey, userID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
