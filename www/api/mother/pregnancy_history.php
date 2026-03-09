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
    // 🔎 GET MOTHER ID
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

    // 📚 FETCH PREGNANCY HISTORY
    $stmt = $conn->prepare("
        SELECT
            p.pregnancy_id,
            p.last_menstrual_period,
            p.expected_date_of_delivery,
            p.outcome,
            p.outcome_date,
            p.gestational_age_at_end,
            p.status,
            d.delivery_date,
            d.place_of_delivery,
            d.delivery_method
        FROM pregnancies p
        LEFT JOIN deliveries d
            ON p.pregnancy_id = d.pregnancy_id
        WHERE p.mother_id = ?
        ORDER BY p.created_at DESC
    ");
    $stmt->bind_param("i", $mother['mother_id']);
    $stmt->execute();

    $history = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);

    foreach ($history as &$record) {
        if ($record['delivery_method']) {
            $record['method_display'] =
                ucfirst(strtolower($record['delivery_method']));
        } else {
            $record['method_display'] =
                $record['outcome'] === 'live_birth'
                    ? 'Normal Delivery'
                    : 'Not applicable';
        }
    }

    echo json_encode([
        'success' => true,
        'history' => $history,
        'count'   => count($history)
    ]);
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Failed to fetch pregnancy history',
        'error'   => $e->getMessage()
    ]);
}
