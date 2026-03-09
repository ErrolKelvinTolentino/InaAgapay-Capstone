<?php
// api/mother/records.php

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");

// Include your database connection
require_once __DIR__ . '/../db.php';

$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? '';

// Validate Authorization header
if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized - No valid Authorization header'
    ]);
    exit;
}

$token = $matches[1];

// Validate token and get user info
$stmt = $conn->prepare("
    SELECT a.account_id, a.account_type, a.email_address, 
           a.first_name, a.last_name, m.mother_id
    FROM accounts a
    LEFT JOIN mothers m ON a.account_id = m.account_id
    WHERE a.last_login_token = ?
      AND a.status = 'active'
    LIMIT 1
");
$stmt->bind_param("s", $token);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows !== 1) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid or expired token'
    ]);
    exit;
}

$user = $result->fetch_assoc();

// Only mother accounts can access this endpoint
if ($user['account_type'] != 'mother') {
    http_response_code(403);
    echo json_encode([
        'success' => false, 
        'message' => 'Access denied - mother account required'
    ]);
    exit;
}

$mother_id = $user['mother_id'];

if (!$mother_id) {
    http_response_code(404);
    echo json_encode([
        'success' => false, 
        'message' => 'Mother profile not found for this account'
    ]);
    exit;
}

try {
    // Get current pregnancy if exists
    $current_pregnancy = null;
    $preg_stmt = $conn->prepare("
        SELECT pregnancy_id, last_menstrual_period, expected_date_of_delivery, 
               pregnancy_risk_level, status,
               ROUND(DATEDIFF(CURDATE(), last_menstrual_period) / 7, 1) as gestational_weeks
        FROM pregnancies 
        WHERE mother_id = ? AND status = 'ongoing'
        ORDER BY created_at DESC 
        LIMIT 1
    ");
    $preg_stmt->bind_param("i", $mother_id);
    $preg_stmt->execute();
    $preg_result = $preg_stmt->get_result();
    
    if ($preg_result->num_rows > 0) {
        $current_pregnancy = $preg_result->fetch_assoc();
    }
    
    // Count prenatal checkups (all pregnancies)
    $prenatal_count = 0;
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM prenatal_checkups pc
        INNER JOIN pregnancies p ON pc.pregnancy_id = p.pregnancy_id
        WHERE p.mother_id = ?
    ");
    $stmt->bind_param("i", $mother_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $prenatal_count = $result->fetch_assoc()['count'];
    
    // Count ultrasounds (all pregnancies)
    $ultrasound_count = 0;
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM ultrasounds u
        INNER JOIN pregnancies p ON u.pregnancy_id = p.pregnancy_id
        WHERE p.mother_id = ?
    ");
    $stmt->bind_param("i", $mother_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $ultrasound_count = $result->fetch_assoc()['count'];
    
    // Count lab tests (all pregnancies)
    $lab_count = 0;
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM lab_tests lt
        INNER JOIN pregnancies p ON lt.pregnancy_id = p.pregnancy_id
        WHERE p.mother_id = ?
    ");
    $stmt->bind_param("i", $mother_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $lab_count = $result->fetch_assoc()['count'];
    
    // Count total pregnancies
    $pregnancy_count = 0;
    $preg_stmt = $conn->prepare("SELECT COUNT(*) as count FROM pregnancies WHERE mother_id = ?");
    $preg_stmt->bind_param("i", $mother_id);
    $preg_stmt->execute();
    $preg_result = $preg_stmt->get_result();
    $pregnancy_count = $preg_result->fetch_assoc()['count'];
    
    echo json_encode([
        'success' => true,
        'records' => [
            'prenatal_count' => $prenatal_count,
            'ultrasound_count' => $ultrasound_count,
            'lab_count' => $lab_count,
            'pregnancy_count' => $pregnancy_count,
            'current_pregnancy' => $current_pregnancy
        ]
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false, 
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>