<?php
require_once __DIR__ . '/../db.php';

// swallow ANY accidental auth output
ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

header('Content-Type: application/json');

try {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON payload');
    }

    $pdo->beginTransaction();

    // ===== ACCOUNT =====
    $acc = $input['account'] ?? [];
    if (empty($acc['email_address'])) {
        throw new Exception('Email is required');
    }

    $stmt = $pdo->prepare("
        INSERT INTO accounts (
            email_address, account_type,
            first_name, middle_name, last_name, extension_name,
            phone_number, is_verified
        ) VALUES (?, 'mother', ?, ?, ?, ?, ?, 1)
    ");
    $stmt->execute([
        $acc['email_address'],
        $acc['first_name'] ?? null,
        $acc['middle_name'] ?? null,
        $acc['last_name'] ?? null,
        $acc['extension_name'] ?? null,
        $acc['phone_number'] ?? null
    ]);

    $accountId = $pdo->lastInsertId();

    // ===== MOTHER =====
    $addr = $input['address'] ?? [];
    $stmt = $pdo->prepare("
        INSERT INTO mothers (
            account_id, house_number, street,
            barangay, city_municipality, province
        ) VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $accountId,
        $addr['house_number'] ?? null,
        $addr['street'] ?? null,
        $addr['barangay'] ?? null,
        $addr['city_municipality'] ?? null,
        $addr['province'] ?? null
    ]);

    $motherId = $pdo->lastInsertId();

    // ===== EMERGENCY CONTACT =====
    if (!empty($input['emergency_contact'])) {
        $ec = $input['emergency_contact'];
        $stmt = $pdo->prepare("
            INSERT INTO emergency_contacts (
                mother_id, first_name, middle_name,
                last_name, extension_name,
                phone_number, email_address
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $motherId,
            $ec['first_name'] ?? null,
            $ec['middle_name'] ?? null,
            $ec['last_name'] ?? null,
            $ec['extension_name'] ?? null,
            $ec['phone_number'] ?? null,
            $ec['email_address'] ?? null
        ]);
    }

    // ===== MEDICAL CONDITIONS =====
    if (!empty($input['medical_conditions'])) {
        $stmt = $pdo->prepare("
            INSERT INTO medical_conditions (mother_id, condition_name)
            VALUES (?, ?)
        ");
        foreach ($input['medical_conditions'] as $c) {
            $stmt->execute([$motherId, $c]);
        }
    }

    // ===== ALLERGIES =====
    if (!empty($input['allergies'])) {
        $stmt = $pdo->prepare("
            INSERT INTO allergies (
                mother_id, allergen, diagnosis_date, treatment
            ) VALUES (?, ?, ?, ?)
        ");
        foreach ($input['allergies'] as $a) {
            $stmt->execute([
                $motherId,
                $a['allergen'] ?? null,
                $a['diagnosis_date'] ?? null,
                $a['treatment'] ?? null
            ]);
        }
    }

    // ===== PREGNANCY =====
    if (!empty($input['pregnancy'])) {
        $p = $input['pregnancy'];
        $stmt = $pdo->prepare("
            INSERT INTO pregnancies (
                mother_id, pregnancy_risk_level,
                last_menstrual_period,
                expected_date_of_delivery,
                status
            ) VALUES (?, ?, ?, ?, 'ongoing')
        ");
        $stmt->execute([
            $motherId,
            $p['pregnancy_risk_level'] ?? 'low',
            $p['last_menstrual_period'] ?? null,
            $p['expected_date_of_delivery'] ?? null
        ]);
    }

    $pdo->commit();

    echo json_encode([
        'success' => true,
        'mother_id' => $motherId
    ]);

} catch (Throwable $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
