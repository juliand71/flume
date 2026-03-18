package auth

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type contextKey string

const UserIDKey contextKey = "user_id"

type jwks struct {
	Keys []jwk `json:"keys"`
}

type jwk struct {
	Kid string `json:"kid"`
	Kty string `json:"kty"`
	Crv string `json:"crv"`
	Alg string `json:"alg"`
	// RSA fields
	N string `json:"n"`
	E string `json:"e"`
	// EC fields
	X string `json:"x"`
	Y string `json:"y"`
}

// FetchPublicKeys fetches public keys from the Supabase JWKS endpoint.
// Supports RS256 (RSA) and ES256 (ECDSA) keys.
func FetchPublicKeys(supabaseURL string) (map[string]any, error) {
	url := strings.TrimRight(supabaseURL, "/") + "/auth/v1/.well-known/jwks.json"
	resp, err := http.Get(url) //nolint:gosec
	if err != nil {
		return nil, fmt.Errorf("fetching JWKS: %w", err)
	}
	defer resp.Body.Close()

	var set jwks
	if err := json.NewDecoder(resp.Body).Decode(&set); err != nil {
		return nil, fmt.Errorf("decoding JWKS: %w", err)
	}

	keys := make(map[string]any, len(set.Keys))
	for _, k := range set.Keys {
		switch k.Kty {
		case "RSA":
			pub, err := parseRSAPublicKey(k)
			if err != nil {
				return nil, fmt.Errorf("parsing RSA key %q: %w", k.Kid, err)
			}
			keys[k.Kid] = pub
		case "EC":
			pub, err := parseECPublicKey(k)
			if err != nil {
				return nil, fmt.Errorf("parsing EC key %q: %w", k.Kid, err)
			}
			keys[k.Kid] = pub
		}
	}
	return keys, nil
}

func parseRSAPublicKey(k jwk) (*rsa.PublicKey, error) {
	nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
	if err != nil {
		return nil, fmt.Errorf("decoding n: %w", err)
	}
	eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
	if err != nil {
		return nil, fmt.Errorf("decoding e: %w", err)
	}
	return &rsa.PublicKey{
		N: new(big.Int).SetBytes(nBytes),
		E: int(new(big.Int).SetBytes(eBytes).Int64()),
	}, nil
}

func parseECPublicKey(k jwk) (*ecdsa.PublicKey, error) {
	xBytes, err := base64.RawURLEncoding.DecodeString(k.X)
	if err != nil {
		return nil, fmt.Errorf("decoding x: %w", err)
	}
	yBytes, err := base64.RawURLEncoding.DecodeString(k.Y)
	if err != nil {
		return nil, fmt.Errorf("decoding y: %w", err)
	}
	var curve elliptic.Curve
	switch k.Crv {
	case "P-256":
		curve = elliptic.P256()
	case "P-384":
		curve = elliptic.P384()
	case "P-521":
		curve = elliptic.P521()
	default:
		return nil, fmt.Errorf("unsupported curve: %s", k.Crv)
	}
	return &ecdsa.PublicKey{
		Curve: curve,
		X:     new(big.Int).SetBytes(xBytes),
		Y:     new(big.Int).SetBytes(yBytes),
	}, nil
}

// Middleware validates Supabase JWTs (ES256 or RS256) using fetched public keys.
func Middleware(keys map[string]any) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			authHeader := r.Header.Get("Authorization")
			if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
				writeError(w, http.StatusUnauthorized, "missing authorization header")
				return
			}

			tokenString := strings.TrimPrefix(authHeader, "Bearer ")

			token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
				switch token.Method.(type) {
				case *jwt.SigningMethodECDSA, *jwt.SigningMethodRSA:
					// valid
				default:
					return nil, jwt.ErrSignatureInvalid
				}
				kid, _ := token.Header["kid"].(string)
				key, ok := keys[kid]
				if !ok {
					for _, k := range keys {
						return k, nil
					}
					return nil, fmt.Errorf("no public key for kid %q", kid)
				}
				return key, nil
			}, jwt.WithValidMethods([]string{"RS256", "ES256"}))

			if err != nil || !token.Valid {
				writeError(w, http.StatusUnauthorized, "invalid token")
				return
			}

			sub, err := token.Claims.GetSubject()
			if err != nil || sub == "" {
				writeError(w, http.StatusUnauthorized, "missing subject claim")
				return
			}

			ctx := context.WithValue(r.Context(), UserIDKey, sub)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

func UserID(ctx context.Context) string {
	if v, ok := ctx.Value(UserIDKey).(string); ok {
		return v
	}
	return ""
}

func writeError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]string{"error": message})
}
