<?php
// db.php
// Centralized database connection file
// IMPORTANT: Do NOT echo or print anything here

error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// AlwaysData MySQL credentials
$DB_HOST = 'mysql-inaagapay.alwaysdata.net';
$DB_USER = 'inaagapay';
$DB_PASS = 'Mine@0729';
$DB_NAME = 'inaagapay_db';

// Create MySQLi connection
$conn = new mysqli($DB_HOST, $DB_USER, $DB_PASS, $DB_NAME);

// Handle connection failure safely (JSON only)
if ($conn->connect_error) {
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => 'Database connection failed'
    ]);
    exit;
}

// Set charset for proper UTF-8 + JSON handling
$conn->set_charset('utf8mb4');

// NO closing PHP tag
