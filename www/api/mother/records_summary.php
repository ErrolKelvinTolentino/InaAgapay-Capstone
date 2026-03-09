<?php
require_once __DIR__ . '/../db.php';

header('Content-Type: application/json');

/**
 * ----------------------------------------------------------------
 * 1. GET AUTH TOKEN FROM HEADER
 * ----------------------------------------------------------------
 */
$headers = getallheaders();
$authHeader = $headers['Authorization'] ?? '';

if (!preg_match('/Bearer\s(\S+)/', $authHeader, $matches)) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Unauthorized'
    ]);
    exit;
}

$token = $matches[1];

/**
 * ----------------------------------------------------------------
 * 2. VALIDATE TOKEN & GET ACCOUNT
 * ----------------------------------------------------------------
 */
$stmt = $conn->prepare("
    SELECT account_id
    FROM accounts
    WHERE last_login_token = ?
    LIMIT 1
");
$stmt->bind_param("s", $token);
$stmt->execute();
$accountResult = $stmt->get_result();

if ($accountResult->num_rows !== 1) {
    http_response_code(401);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid token'
    ]);
    exit;
}

$account = $accountResult->fetch_assoc();
$accountId = (int) $account['account_id'];

/**
 * ----------------------------------------------------------------
 * 3. GET MOTHER ID
 * ----------------------------------------------------------------
 */
$stmt = $conn->prepare("
    SELECT mother_id
    FROM mothers
    WHERE account_id = ?
    LIMIT 1
");
$stmt->bind_param("i", $accountId);
$stmt->execute();
$motherResult = $stmt->get_result();

if ($motherResult->num_rows !== 1) {
    echo json_encode([
        'success' => false,
        'message' => 'Mother profile not found'
    ]);
    exit;
}

$mother = $motherResult->fetch_assoc();
$motherId = (int) $mother['mother_id'];

/**
 * ----------------------------------------------------------------
 * 4. COUNT RECORDS
 * ----------------------------------------------------------------
 */

/* Pregnancy count */
$stmt = $conn->prepare("
    SELECT COUNT(*) AS total
    FROM pregnancies
    WHERE mother_id = ?
");
$stmt->bind_param("i", $motherId);
$stmt->execute();
$pregnancyCount = (int) $stmt->get_result()->fetch_assoc()['total'];

/* Prenatal checkups */
$stmt = $conn->prepare("
    SELECT COUNT(*) AS total
    FROM prenatal_checkups pc
    INNER JOIN pregnancies p ON pc.pregnancy_id = p.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param("i", $motherId);
$stmt->execute();
$prenatalCount = (int) $stmt->get_result()->fetch_assoc()['total'];

/* Ultrasounds */
$stmt = $conn->prepare("
    SELECT COUNT(*) AS total
    FROM ultrasounds u
    INNER JOIN pregnancies p ON u.pregnancy_id = p.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param("i", $motherId);
$stmt->execute();
$ultrasoundCount = (int) $stmt->get_result()->fetch_assoc()['total'];

/* Laboratory tests */
$stmt = $conn->prepare("
    SELECT COUNT(*) AS total
    FROM lab_tests l
    INNER JOIN pregnancies p ON l.pregnancy_id = p.pregnancy_id
    WHERE p.mother_id = ?
");
$stmt->bind_param("i", $motherId);
$stmt->execute();
$labCount = (int) $stmt->get_result()->fetch_assoc()['total'];

/**
 * ----------------------------------------------------------------
 * 5. RESPONSE
 * ----------------------------------------------------------------
 */
echo json_encode([
    'success' => true,
    'prenatal_count' => $prenatalCount,
    'ultrasound_count' => $ultrasoundCount,
    'lab_count' => $labCount,
    'pregnancy_count' => $pregnancyCount
]);
