<?php
require_once __DIR__ . '/../auth/auth_check.php';

header('Content-Type: application/json');

$childId = $_GET['child_id'] ?? null;

if (!$childId) {
    echo json_encode([
        'success' => false,
        'message' => 'Missing child_id'
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
    
    /**
     * ================= CHILD BASIC INFO =================
     */
    $stmt = $conn->prepare("
        SELECT
            c.child_id,
            c.first_name,
            c.middle_name,
            c.last_name,
            c.extension_name,
            c.sex,
            bd.birthdate,
            TIMESTAMPDIFF(YEAR, bd.birthdate, CURDATE()) AS age_years
        FROM children c
        LEFT JOIN birth_details bd ON bd.child_id = c.child_id
        WHERE c.child_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("i", $childId);
    $stmt->execute();
    $child = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$child) {
        echo json_encode([
            'success' => false,
            'message' => 'Child not found'
        ]);
        exit;
    }

    /**
     * ================= BIRTH DETAILS =================
     */
    $stmt = $conn->prepare("
        SELECT
            birthdate,
            birth_weight,
            birth_length,
            head_circumference,
            birthplace_city_municipality,
            birthplace_province,
            birth_complications
        FROM birth_details
        WHERE child_id = ?
        LIMIT 1
    ");
    $stmt->bind_param("i", $childId);
    $stmt->execute();
    $birth = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    /**
     * ================= LATEST GROWTH =================
     */
    $stmt = $conn->prepare("
        SELECT
            child_height,
            child_weight,
            ROUND(child_weight / POW(child_height / 100, 2), 1) AS bmi
        FROM child_details
        WHERE child_id = ?
        ORDER BY created_at DESC
        LIMIT 1
    ");
    $stmt->bind_param("i", $childId);
    $stmt->execute();
    $growth = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    /**
     * ================= LATEST IMMUNIZATION =================
     */
    $stmt = $conn->prepare("
        SELECT
            v.vaccine_name,
            v.dose_number,
            ir.vaccination_date
        FROM immunization_record ir
        INNER JOIN vaccines v ON v.vaccine_id = ir.vaccine_id
        WHERE ir.child_id = ?
        ORDER BY ir.vaccination_date DESC, ir.immunization_record_id DESC
        LIMIT 1
    ");
    $stmt->bind_param("i", $childId);
    $stmt->execute();
    $immunization = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    /**
     * ================= FINAL RESPONSE =================
     */
    echo json_encode([
        'success' => true,
        'child' => $child,
        'birth' => $birth ?: [],
        'growth' => $growth ?: [],
        'immunization' => $immunization ?: []
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
    exit;
}