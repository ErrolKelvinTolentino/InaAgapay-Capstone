<?php
require_once __DIR__ . '/../db.php';
require_once __DIR__ . '/../auth/auth_check.php';

header('Content-Type: application/json');

// Get JSON input
$json = file_get_contents('php://input');
$data = json_decode($json, true);

if (!$data) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data'
    ]);
    exit;
}

$childId = $data['child_id'] ?? null;
$height  = $data['height'] ?? null;
$weight  = $data['weight'] ?? null;
$bmi     = $data['bmi'] ?? null;
$remarks = $data['remarks'] ?? null;

if (!$childId || !$height || !$weight) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields: child_id, height, and weight are required'
    ]);
    exit;
}

// Verify the child belongs to a mother in the midwife's BHC
try {
    // Get midwife's BHC
    $authAccountId = $AUTH_USER['account_id'] ?? null;
    if (!$authAccountId) {
        throw new Exception('Authentication required');
    }
    
    $midwifeStmt = $conn->prepare("
        SELECT m.assigned_bhc_id 
        FROM midwives m 
        WHERE m.account_id = ?
    ");
    $midwifeStmt->bind_param("i", $authAccountId);
    $midwifeStmt->execute();
    $midwifeResult = $midwifeStmt->get_result();
    
    if ($midwifeResult->num_rows === 0) {
        throw new Exception('Midwife not found');
    }
    
    $midwife = $midwifeResult->fetch_assoc();
    $midwifeBhcId = $midwife['assigned_bhc_id'];
    
    // Verify child belongs to a mother in the same BHC
    $verifyStmt = $conn->prepare("
        SELECT c.child_id 
        FROM children c 
        JOIN mothers m ON c.mother_id = m.mother_id 
        WHERE c.child_id = ? 
        AND m.assigned_bhc_id = ?
    ");
    $verifyStmt->bind_param("ii", $childId, $midwifeBhcId);
    $verifyStmt->execute();
    $verifyResult = $verifyStmt->get_result();
    
    if ($verifyResult->num_rows === 0) {
        throw new Exception('Child not found or not in your assigned BHC');
    }
    
    // Insert growth record
    $stmt = $conn->prepare("
        INSERT INTO child_details (child_id, child_height, child_weight)
        VALUES (?, ?, ?)
    ");
    
    if (!$stmt) {
        throw new Exception('Database prepare error: ' . $conn->error);
    }
    
    $stmt->bind_param("idd", $childId, $height, $weight);
    
    if ($stmt->execute()) {
        $growthId = $conn->insert_id;
        
        echo json_encode([
            'success' => true,
            'growth_id' => $growthId,
            'message' => 'Growth record added successfully'
        ]);
    } else {
        throw new Exception('Database insert error: ' . $conn->error);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
    exit;
}