package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

var db *sql.DB

func main() {
	// 1. Load config from environment variables
	dbHost := getEnv("DB_HOST", "pgbouncer")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USER", "prod_backend_hades_user")
	dbPass := getEnv("DB_PASSWORD", "")
	dbName := getEnv("DB_NAME", "prod_hades_user")
	dbSSLMode := getEnv("DB_SSLMODE", "disable") // local to pgbouncer service

	// 2. Build connection string
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		dbHost, dbPort, dbUser, dbPass, dbName, dbSSLMode)

	// 3. Initialize DB connection
	var err error
	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Error opening database connection: %v", err)
	}

	// Verify connection
	if err := db.Ping(); err != nil {
		log.Printf("Warning: Database ping failed at startup: %v", err)
	} else {
		log.Println("Successfully connected to database (PgBouncer)")
	}

	// 4. Initialize Gin router
	r := gin.Default()

	// Health endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	})

	// DB connectivity test endpoint
	r.GET("/db-test", func(c *gin.Context) {
		if err := db.Ping(); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status": "error",
				"error":  fmt.Sprintf("Database ping failed: %v", err),
			})
			return
		}

		var dbTime string
		err := db.QueryRow("SELECT NOW()").Scan(&dbTime)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{
				"status": "error",
				"error":  fmt.Sprintf("Failed to query SELECT NOW(): %v", err),
			})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"status":      "success",
			"message":     "Connected to database successfully through PgBouncer!",
			"database":    dbName,
			"db_host":     dbHost,
			"server_time": dbTime,
		})
	})

	// Run server
	port := getEnv("PORT", "8080")
	log.Printf("Starting server on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}

func getEnv(key, fallback string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return fallback
}
