<?php
// Enable error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Start output buffering
ob_start();

// Include required files
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

// Clear any previous output
ob_clean();

// Set JSON header
header('Content-Type: application/json');

// Check if user is authenticated
if (empty($AUTH_USER)) {
    echo json_encode([
        'success' => false,
        'message' => 'Authentication required. Please log in.',
        'error_code' => 'UNAUTHORIZED'
    ]);
    exit;
}

try {
    $accountId = $AUTH_USER['account_id'];
    
    // Get mother_id
    $stmt = $conn->prepare("SELECT mother_id FROM mothers WHERE account_id = ?");
    if (!$stmt) {
        throw new Exception("Mother query prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $accountId);
    if (!$stmt->execute()) {
        throw new Exception("Mother query execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $mother = $result->fetch_assoc();
    
    if (!$mother) {
        echo json_encode([
            'success' => true,
            'message' => 'Mother profile not found',
            'latest' => null,
            'history' => [],
            'total' => 0
        ], JSON_PRETTY_PRINT);
        exit;
    }
    
    $motherId = $mother['mother_id'];
    
    // Get pregnancies for this mother
    $stmt = $conn->prepare("
        SELECT pregnancy_id 
        FROM pregnancies 
        WHERE mother_id = ?
        ORDER BY created_at DESC
    ");
    
    if (!$stmt) {
        throw new Exception("Pregnancy query prepare failed: " . $conn->error);
    }
    
    $stmt->bind_param("i", $motherId);
    if (!$stmt->execute()) {
        throw new Exception("Pregnancy query execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $pregnancyIds = [];
    
    while ($row = $result->fetch_assoc()) {
        $pregnancyIds[] = $row['pregnancy_id'];
    }
    
    // If no pregnancies found
    if (empty($pregnancyIds)) {
        echo json_encode([
            'success' => true,
            'message' => 'No pregnancies found',
            'latest' => null,
            'history' => [],
            'total' => 0
        ], JSON_PRETTY_PRINT);
        exit;
    }
    
    // Build placeholders for IN clause
    $placeholders = implode(',', array_fill(0, count($pregnancyIds), '?'));
    
    // Query prenatal checkups - FIXED for your database schema
    // Note: Using INNER JOIN instead of LEFT JOIN since midwife_id is NOT NULL
    $query = "
        SELECT
            pc.prenatal_checkup_id,
            pc.pregnancy_id,
            pc.age_of_gestation,
            pc.checkup_weight,
            pc.blood_pressure_systolic,
            pc.blood_pressure_diastolic,
            pc.fetal_position,
            pc.fetal_heart_beat,
            pc.fetal_heart_tone,
            pc.td_vaccine_dose,
            pc.edema,
            pc.remarks,
            DATE(pc.checkup_datetime) as checkup_date,
            pc.next_schedule,
            a.first_name as midwife_first_name,
            a.last_name as midwife_last_name
        FROM prenatal_checkups pc
        INNER JOIN midwives m ON pc.midwife_id = m.midwife_id
        INNER JOIN accounts a ON m.account_id = a.account_id
        WHERE pc.pregnancy_id IN ($placeholders)
        ORDER BY pc.checkup_datetime DESC
    ";
    
    $stmt = $conn->prepare($query);
    if (!$stmt) {
        throw new Exception("Checkup query prepare failed: " . $conn->error);
    }
    
    // Bind parameters
    $types = str_repeat('i', count($pregnancyIds));
    $stmt->bind_param($types, ...$pregnancyIds);
    
    if (!$stmt->execute()) {
        throw new Exception("Checkup query execute failed: " . $stmt->error);
    }
    
    $result = $stmt->get_result();
    $checkups = [];
    
    while ($row = $result->fetch_assoc()) {
        // Convert null values to empty strings
        foreach ($row as $key => $value) {
            if ($value === null) {
                $row[$key] = '';
            }
        }
        $checkups[] = $row;
    }
    
    // Get the latest checkup
    $latest = !empty($checkups) ? $checkups[0] : null;
    
    // Build response
    $response = [
        'success' => true,
        'message' => 'Success',
        'latest' => $latest,
        'history' => $checkups,
        'total' => count($checkups)
    ];
    
    echo json_encode($response, JSON_PRETTY_PRINT | JSON_NUMERIC_CHECK);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage(),
        'error' => $e->getMessage(),
        'latest' => null,
        'history' => [],
        'total' => 0
    ], JSON_PRETTY_PRINT);
}

// End buffering
ob_end_flush();