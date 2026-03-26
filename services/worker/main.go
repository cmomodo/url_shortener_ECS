package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/sqs"
	_ "github.com/lib/pq"
)

var db *sql.DB
var sqsClient *sqs.SQS

type ClickEvent struct {
	ShortCode string `json:"short_code"`
	IP        string `json:"ip"`
	UserAgent string `json:"user_agent"`
	Referer   string `json:"referer"`
	Timestamp string `json:"timestamp"`
}

type SQSMessage struct {
	Body          string
	ReceiptHandle string
}

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
	db.SetConnMaxLifetime(5 * time.Minute)
	waitForDB()
	migrate()

	sqsQueue := os.Getenv("SQS_QUEUE_URL")
	if sqsQueue == "" {
		log.Fatal("SQS_QUEUE_URL is required")
	}

	sqsClient = newSQSClient()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Health check endpoint
	go func() {
		mux := http.NewServeMux()
		mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
			status := "ok"
			if err := db.Ping(); err != nil {
				status = "unhealthy"
				w.WriteHeader(http.StatusServiceUnavailable)
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(map[string]string{"status": status, "service": "worker"})
		})
		port := getEnv("HEALTH_PORT", "8090")
		log.Printf("Worker health check on :%s", port)
		http.ListenAndServe(":"+port, mux)
	}()

	// Graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		log.Println("Shutting down worker...")
		cancel()
	}()

	log.Println("Analytics worker started, polling SQS...")
	pollSQS(ctx, sqsQueue)
}

func migrate() {
	migrations := []string{
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
	for _, m := range migrations {
		if _, err := db.Exec(m); err != nil {
			log.Fatalf("Migration failed: %v", err)
		}
	}
	log.Println("Worker migrations complete")
}

func pollSQS(ctx context.Context, queueURL string) {
	for {
		select {
		case <-ctx.Done():
			log.Println("Worker stopped")
			return
		default:
			messages := receiveSQSMessages(queueURL)
			for _, msg := range messages {
				if err := processClickEvent(msg.Body); err != nil {
					log.Printf("Failed to process event: %v", err)
					continue
				}
				if err := deleteSQSMessage(queueURL, msg.ReceiptHandle); err != nil {
					log.Printf("Failed to delete message: %v", err)
					continue
				}
				log.Printf("Processed click event: %s", msg.Body)
			}
			if len(messages) == 0 {
				time.Sleep(5 * time.Second)
			}
		}
	}
}

func receiveSQSMessages(queueURL string) []SQSMessage {
	output, err := sqsClient.ReceiveMessage(&sqs.ReceiveMessageInput{
		QueueUrl:            aws.String(queueURL),
		MaxNumberOfMessages: aws.Int64(10),
		WaitTimeSeconds:     aws.Int64(20),
	})
	if err != nil {
		log.Printf("Failed to receive SQS messages: %v", err)
		return nil
	}

	messages := make([]SQSMessage, 0, len(output.Messages))
	for _, msg := range output.Messages {
		if msg.Body == nil || msg.ReceiptHandle == nil {
			continue
		}
		messages = append(messages, SQSMessage{
			Body:          *msg.Body,
			ReceiptHandle: *msg.ReceiptHandle,
		})
	}

	return messages
}

func deleteSQSMessage(queueURL, receiptHandle string) error {
	_, err := sqsClient.DeleteMessage(&sqs.DeleteMessageInput{
		QueueUrl:      aws.String(queueURL),
		ReceiptHandle: aws.String(receiptHandle),
	})
	return err
}

func newSQSClient() *sqs.SQS {
	region := getEnv("AWS_REGION", getEnv("AWS_DEFAULT_REGION", "us-east-1"))
	cfg := aws.NewConfig().WithRegion(region)

	if endpoint := os.Getenv("AWS_ENDPOINT_URL"); endpoint != "" {
		cfg = cfg.WithEndpoint(endpoint)
	}

	accessKey := getEnv("AWS_ACCESS_KEY_ID", "test")
	secretKey := getEnv("AWS_SECRET_ACCESS_KEY", "test")
	sessionToken := os.Getenv("AWS_SESSION_TOKEN")
	cfg = cfg.WithCredentials(credentials.NewStaticCredentials(accessKey, secretKey, sessionToken))

	sess, err := session.NewSession(cfg)
	if err != nil {
		log.Fatalf("Failed to create SQS session: %v", err)
	}

	return sqs.New(sess)
}

func processClickEvent(raw string) error {
	var event ClickEvent
	if err := json.Unmarshal([]byte(raw), &event); err != nil {
		return err
	}

	clickedAt, err := time.Parse(time.RFC3339, event.Timestamp)
	if err != nil {
		clickedAt = time.Now().UTC()
	}

	// Insert raw click event
	_, err = db.Exec(
		`INSERT INTO click_events (short_code, ip_address, user_agent, referer, clicked_at)
		 VALUES ($1, $2, $3, $4, $5)`,
		event.ShortCode, event.IP, event.UserAgent, event.Referer, clickedAt,
	)
	if err != nil {
		return err
	}

	// Update hourly aggregation
	hour := clickedAt.Truncate(time.Hour)
	_, err = db.Exec(
		`INSERT INTO click_stats_hourly (short_code, hour, clicks, unique_ips)
		 VALUES ($1, $2, 1, 1)
		 ON CONFLICT (short_code, hour)
		 DO UPDATE SET clicks = click_stats_hourly.clicks + 1`,
		event.ShortCode, hour,
	)

	return err
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
