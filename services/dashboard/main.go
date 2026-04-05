package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

var db *sql.DB

func main() {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	var err error
	db, err = sql.Open("postgres", dbURL)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(3)
	waitForDB()
	migrate()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", handleHealth)
	mux.HandleFunc("/summary", handleSummary)
	mux.HandleFunc("/url/", handleURLStats)
	mux.HandleFunc("/recent", handleRecent)
	mux.HandleFunc("/top", handleTop)

	port := getEnv("PORT", "8081")
	log.Printf("Dashboard API listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, corsMiddleware(mux)))
}

func migrate() {
	statements := []string{
		`CREATE TABLE IF NOT EXISTS click_events (
			id SERIAL PRIMARY KEY,
			short_code VARCHAR(16) NOT NULL,
			ip_address VARCHAR(45),
			user_agent TEXT,
			referer TEXT,
			clicked_at TIMESTAMP NOT NULL,
			processed_at TIMESTAMP DEFAULT NOW()
		)`,
		`CREATE INDEX IF NOT EXISTS idx_click_events_short_code ON click_events(short_code)`,
		`CREATE INDEX IF NOT EXISTS idx_click_events_clicked_at ON click_events(clicked_at)`,
		`CREATE TABLE IF NOT EXISTS click_stats_hourly (
			short_code VARCHAR(16) NOT NULL,
			hour TIMESTAMP NOT NULL,
			clicks INTEGER DEFAULT 0,
			unique_ips INTEGER DEFAULT 0,
			PRIMARY KEY (short_code, hour)
		)`,
	}
	for _, s := range statements {
		if _, err := db.Exec(s); err != nil {
			log.Fatalf("Migration failed: %v", err)
		}
	}
	log.Println("Dashboard migrations complete")
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	status := "ok"
	if err := db.Ping(); err != nil {
		status = "unhealthy"
		w.WriteHeader(http.StatusServiceUnavailable)
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": status, "service": "dashboard"})
}

func handleSummary(w http.ResponseWriter, r *http.Request) {
	today := time.Now().UTC().Truncate(24 * time.Hour)

	var totalURLs, totalClicks, clicksToday int
	db.QueryRow("SELECT COUNT(*) FROM urls").Scan(&totalURLs)
	db.QueryRow("SELECT COALESCE(SUM(clicks), 0) FROM click_stats_hourly").Scan(&totalClicks)
	db.QueryRow(
		"SELECT COALESCE(SUM(clicks), 0) FROM click_stats_hourly WHERE hour >= $1",
		today,
	).Scan(&clicksToday)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"total_urls":   totalURLs,
		"total_clicks": totalClicks,
		"clicks_today": clicksToday,
	})
}

func handleURLStats(w http.ResponseWriter, r *http.Request) {
	code := strings.TrimPrefix(r.URL.Path, "/url/")
	if code == "" {
		httpError(w, "provide a short code", http.StatusBadRequest)
		return
	}

	var url string
	var clicks int
	var createdAt time.Time
	err := db.QueryRow(
		"SELECT url, clicks, created_at FROM urls WHERE id = $1", code,
	).Scan(&url, &clicks, &createdAt)
	if err != nil {
		if err == sql.ErrNoRows {
			httpError(w, "not found", http.StatusNotFound)
			return
		}
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}

	// Hourly stats for last 24 hours
	rows, err := db.Query(
		`SELECT hour, clicks FROM click_stats_hourly
		 WHERE short_code = $1 AND hour >= NOW() - INTERVAL '24 hours'
		 ORDER BY hour DESC`,
		code,
	)

	type HourlyStat struct {
		Hour   string `json:"hour"`
		Clicks int    `json:"clicks"`
	}

	hourly := []HourlyStat{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var hour time.Time
			var clicks int
			if err := rows.Scan(&hour, &clicks); err != nil {
				httpError(w, "query failed", http.StatusInternalServerError)
				return
			}
			h := HourlyStat{
				Hour:   hour.UTC().Format(time.RFC3339),
				Clicks: clicks,
			}
			hourly = append(hourly, h)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"short_code":   code,
		"url":          url,
		"total_clicks": clicks,
		"created_at":   createdAt.UTC().Format(time.RFC3339),
		"hourly":       hourly,
	})
}

func handleRecent(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(
		`SELECT short_code, ip_address, user_agent, clicked_at
		 FROM click_events ORDER BY clicked_at DESC LIMIT 50`,
	)
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type Click struct {
		ShortCode string `json:"short_code"`
		IP        string `json:"ip"`
		UserAgent string `json:"user_agent"`
		ClickedAt string `json:"clicked_at"`
	}

	clicks := []Click{}
	for rows.Next() {
		var c Click
		var clickedAt time.Time
		if err := rows.Scan(&c.ShortCode, &c.IP, &c.UserAgent, &clickedAt); err != nil {
			httpError(w, "query failed", http.StatusInternalServerError)
			return
		}
		c.ClickedAt = clickedAt.UTC().Format(time.RFC3339)
		clicks = append(clicks, c)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(clicks)
}

func handleTop(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(
		"SELECT id, url, clicks FROM urls ORDER BY clicks DESC LIMIT 10",
	)
	if err != nil {
		httpError(w, "query failed", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type TopURL struct {
		ShortCode string `json:"short_code"`
		URL       string `json:"url"`
		Clicks    int    `json:"clicks"`
	}

	top := []TopURL{}
	for rows.Next() {
		var t TopURL
		rows.Scan(&t.ShortCode, &t.URL, &t.Clicks)
		top = append(top, t)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(top)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func httpError(w http.ResponseWriter, msg string, code int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func waitForDB() {
	for i := 0; i < 30; i++ {
		if err := db.Ping(); err == nil {
			return
		}
		log.Printf("Waiting for database... (%d/30)", i+1)
		time.Sleep(time.Second)
	}
	log.Fatal("Database not ready after 30s")
}
