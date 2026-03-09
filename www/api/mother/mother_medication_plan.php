<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if (($AUTH_USER['account_type'] ?? null) !== 'mother') {
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

try {
    // 🔎 GET mother_id
    $stmt = $conn->prepare("
        SELECT mother_id
        FROM mothers
        WHERE account_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("i", $AUTH_USER['account_id']);
    $stmt->execute();
    $mother = $stmt->get_result()->fetch_assoc();

    if (!$mother) {
        echo json_encode([
            'success' => false,
            'message' => 'Mother profile not found'
        ]);
        exit;
    }

    // 💊 FETCH MEDICATION PLAN
    $stmt = $conn->prepare("
        SELECT
            mother_medication_id,
            mother_medication_name,
            frequency,
            quantity,
            start_date,
            end_date,
            status
        FROM mother_medications
        WHERE mother_id = ?
        ORDER BY created_at DESC
    ");
    $stmt->bind_param("i", $mother['mother_id']);
    $stmt->execute();

    $medications = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    echo json_encode([
        'success' => true,
        'medications' => $medications,
        'count' => count($medications)
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to load medication plan',
        'error' => $e->getMessage()
    ]);
}
