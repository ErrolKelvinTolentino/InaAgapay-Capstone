<?php
require_once __DIR__ . '/../db.php';

// swallow auth output (safety)
ob_start();
require_once __DIR__ . '/../auth/auth_check.php';
ob_end_clean();

header('Content-Type: application/json');

try {
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Invalid JSON payload');
    }

    $conn->begin_transaction();

    // ===== ACCOUNT =====
    $acc = $input['account'] ?? [];

    // 🔥 FIX: allow missing email (auto-generate)
    $email = $acc['email_address'] ?? null;
    if (empty($email)) {
        $email = 'mother_' . uniqid() . '@inaagapay.local';
    }

    $stmt = $conn->prepare("
        INSERT INTO accounts (
            email_address, account_type,
            first_name, middle_name, last_name, extension_name,
            phone_number, is_verified
        ) VALUES (?, 'mother', ?, ?, ?, ?, ?, 1)
    ");
    if (!$stmt) {
        throw new Exception('Prepare failed: ' . $conn->error);
    }
    
    $accFirst = $acc['first_name'] ?? null;
    $accMiddle = $acc['middle_name'] ?? null;
    $accLast = $acc['last_name'] ?? null;
    $accExt = $acc['extension_name'] ?? null;
    $accPhone = $acc['phone_number'] ?? null;
    
    if (!$stmt->bind_param(
        "ssssss",
        $email,
        $accFirst,
        $accMiddle,
        $accLast,
        $accExt,
        $accPhone
    )) {
        throw new Exception('Bind param failed: ' . $stmt->error);
    }
    
    if (!$stmt->execute()) {
        throw new Exception('Execute account insert failed: ' . $stmt->error);
    }

    $accountId = $conn->insert_id;

    // ===== MOTHER =====
    $mother = $input['mother'] ?? ($input['address'] ?? []);
    $assignedBhcId = $mother['assigned_bhc_id'] ?? null;
    $birthdate = $mother['birthdate'] ?? null;
    $stmt = $conn->prepare("
        INSERT INTO mothers (
            account_id, assigned_bhc_id, birthdate,
            house_number, street,
            barangay, city_municipality, province,
            height, weight, blood_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ");
    $stmt->bind_param(
        "iissssssdds",
        $accountId,
        $assignedBhcId,
        $birthdate,
        $mother['house_number'],
        $mother['street'],
        $mother['barangay'],
        $mother['city_municipality'],
        $mother['province'],
        $mother['height_cm'],
        $mother['weight_kg'],
        $mother['blood_type']
    );
    $stmt->execute();

    $motherId = $conn->insert_id;

    // ===== EMERGENCY CONTACT =====
    if (!empty($input['emergency_contact'])) {
        $ec = $input['emergency_contact'];
        $stmt = $conn->prepare("
            INSERT INTO emergency_contacts (
                mother_id, first_name, middle_name,
                last_name, extension_name,
                phone_number, email_address, affiliation,
                house_number, street, barangay, city_municipality, province
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ");
        $stmt->bind_param(
            "issssssssssss",
            $motherId,
            $ec['first_name'],
            $ec['middle_name'],
            $ec['last_name'],
            $ec['extension_name'],
            $ec['phone_number'],
            $ec['email_address'],
            $ec['affiliation'],
            $ec['house_number'],
            $ec['street'],
            $ec['barangay'],
            $ec['city_municipality'],
            $ec['province']
        );
        $stmt->execute();
    }

    // ===== MEDICAL CONDITIONS =====
    if (!empty($input['medical_conditions'])) {
        $stmt = $conn->prepare("
            INSERT INTO medical_conditions (
                mother_id, condition_name, diagnosis_date, status, remarks
            ) VALUES (?, ?, ?, ?, ?)
        ");
        foreach ($input['medical_conditions'] as $c) {
            $stmt->bind_param(
                "issss",
                $motherId,
                $c['condition_name'],
                $c['diagnosis_date'],
                $c['status'],
                $c['remarks']
            );
            $stmt->execute();
        }
    }

    // ===== ALLERGIES =====
    if (!empty($input['allergies'])) {
        $stmt = $conn->prepare("
            INSERT INTO allergies (
                mother_id, allergen, diagnosis_date, status, treatment, remarks
            ) VALUES (?, ?, ?, ?, ?, ?)
        ");
        foreach ($input['allergies'] as $a) {
            $stmt->bind_param(
                "isssss",
                $motherId,
                $a['allergen'],
                $a['diagnosis_date'],
                $a['status'],
                $a['treatment'],
                $a['remarks']
            );
            $stmt->execute();
        }
    }

    // ===== PREGNANCY HISTORY (ended pregnancies) =====
    if (!empty($input['pregnancy_history'])) {
        $pregStmt = $conn->prepare("
            INSERT INTO pregnancies (
                mother_id, pregnancy_risk_level, last_menstrual_period,
                expected_date_of_delivery, status, outcome, outcome_date,
                is_outcome_date_estimated, gestational_age_at_end
            ) VALUES (?, 'low', NULL, NULL, 'ended', ?, ?, ?, ?)
        ");
        $delStmt = $conn->prepare("
            INSERT INTO deliveries (
                pregnancy_id, delivery_date, is_delivery_date_estimated,
                place_of_delivery, delivery_method
            ) VALUES (?, ?, ?, ?, ?)
        ");

        foreach ($input['pregnancy_history'] as $p) {
            $pregStmt->bind_param(
                "issid",
                $motherId,
                $p['outcome'],
                $p['outcome_date'],
                $p['is_outcome_date_estimated'],
                $p['gestational_age_at_end']
            );
            $pregStmt->execute();
            $historyPregnancyId = $conn->insert_id;

            if (in_array($p['outcome'], ['live_birth', 'stillbirth'])) {
                $delStmt->bind_param(
                    "isiss",
                    $historyPregnancyId,
                    $p['outcome_date'],
                    $p['is_outcome_date_estimated'],
                    $p['place_of_delivery'],
                    $p['delivery_method']
                );
                $delStmt->execute();
            }
        }
    }

    // ===== PREGNANCY =====
    $ongoingPregnancyId = null;
    if (!empty($input['pregnancy'])) {
        $p = $input['pregnancy'];
        $stmt = $conn->prepare("
            INSERT INTO pregnancies (
                mother_id, pregnancy_risk_level,
                last_menstrual_period,
                expected_date_of_delivery,
                status
            ) VALUES (?, ?, ?, ?, 'ongoing')
        ");
        $stmt->bind_param(
            "isss",
            $motherId,
            $p['pregnancy_risk_level'],
            $p['last_menstrual_period'],
            $p['expected_date_of_delivery']
        );
        $stmt->execute();
        $ongoingPregnancyId = $conn->insert_id;
    }

    $conn->commit();

    echo json_encode([
        'success' => true,
        'mother_id' => $motherId,
        'pregnancy_id' => $ongoingPregnancyId
    ]);

} catch (Throwable $e) {
    $conn->rollback();
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
