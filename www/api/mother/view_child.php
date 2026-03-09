<?php
require_once __DIR__ . '/../auth/auth_check.php';
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

if ($AUTH_USER['account_type'] !== 'mother') {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'Forbidden']);
    exit;
}

$childId = $_GET['child_id'] ?? null;

if (!$childId) {
    echo json_encode(['success' => false, 'message' => 'Missing child_id']);
    exit;
}

/**
 * Get mother_id
 */
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
    echo json_encode(['success' => false, 'message' => 'Mother not found']);
    exit;
}

$motherId = $mother['mother_id'];

/**
 * Child + birth details
 */
$stmt = $conn->prepare("
    SELECT 
        c.child_id,
        c.first_name,
        c.middle_name,
        c.last_name,
        c.extension_name,
        bd.birthdate,
        bd.birthplace_city_municipality,
        bd.birthplace_province
    FROM children c
    LEFT JOIN birth_details bd ON bd.child_id = c.child_id
    WHERE c.child_id = ?
      AND c.mother_id = ?
    LIMIT 1
");
$stmt->bind_param("ii", $childId, $motherId);
$stmt->execute();
$child = $stmt->get_result()->fetch_assoc();

if (!$child) {
    echo json_encode(['success' => false, 'message' => 'Child not found']);
    exit;
}

/**
 * Latest growth
 */
$stmt = $conn->prepare("
    SELECT child_height, child_weight
    FROM child_details
    WHERE child_id = ?
    ORDER BY created_at DESC
    LIMIT 1
");
$stmt->bind_param("i", $childId);
$stmt->execute();
$growth = $stmt->get_result()->fetch_assoc();

/**
 * ✅ FIXED: Latest immunization (TRUE latest)
 */
$stmt = $conn->prepare("
    SELECT 
        v.vaccine_name,
        ir.vaccination_date
    FROM immunization_record ir
    JOIN vaccines v ON v.vaccine_id = ir.vaccine_id
    WHERE ir.child_id = ?
    ORDER BY 
        ir.vaccination_date DESC,
        ir.immunization_record_id DESC
    LIMIT 1
");
$stmt->bind_param("i", $childId);
$stmt->execute();
$vaccine = $stmt->get_result()->fetch_assoc();

/**
 * Response
 */
echo json_encode([
    'success' => true,
    'child' => [
        'id' => $child['child_id'],
        'full_name' => trim(
            $child['first_name'] . ' ' .
            ($child['middle_name'] ? $child['middle_name'] . '.' : '') . ' ' .
            $child['last_name'] . ' ' .
            ($child['extension_name'] ?? '')
        ),
        'birthdate' => $child['birthdate'],
        'birthplace' => trim(
            ($child['birthplace_city_municipality'] ?? '') . ', ' .
            ($child['birthplace_province'] ?? '')
        ),
    ],
    'growth' => $growth,
    'latest_vaccine' => $vaccine,
]);
