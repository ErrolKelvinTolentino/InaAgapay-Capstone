<?php
require_once __DIR__ . '/../auth/auth_check.php';

header('Content-Type: application/json');

$data = json_decode(file_get_contents('php://input'), true);

if (!$data || !isset($data['mother_id'], $data['child'], $data['birth'])) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid payload'
    ]);
    exit;
}

$motherId = (int) $data['mother_id'];
$child = $data['child'];
$birth = $data['birth'];

$conn->begin_transaction();

try {
    /**
     * INSERT CHILD
     */
    $stmt = $conn->prepare("
        INSERT INTO children (
            mother_id,
            first_name,
            last_name,
            middle_name,
            extension_name,
            sex
        ) VALUES (?, ?, ?, ?, ?, ?)
    ");

    $stmt->bind_param(
        "isssss",
        $motherId,
        $child['first_name'],
        $child['last_name'],
        $child['middle_name'],
        $child['extension_name'],
        $child['sex']
    );

    if (!$stmt->execute()) {
        throw new Exception('Failed to insert child');
    }

    $childId = $stmt->insert_id;

    /**
     * INSERT BIRTH DETAILS
     */
    $stmt = $conn->prepare("
        INSERT INTO birth_details (
            child_id,
            birthdate,
            birth_weight,
            birth_length,
            head_circumference,
            birthplace_city_municipality,
            birthplace_province,
            birth_complications
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ");

    $stmt->bind_param(
        "isdddsss",
        $childId,
        $birth['birthdate'],
        $birth['birth_weight'],
        $birth['birth_length'],
        $birth['head_circumference'],
        $birth['birthplace_city_municipality'],
        $birth['birthplace_province'],
        $birth['birth_complications']
    );

    if (!$stmt->execute()) {
        throw new Exception('Failed to insert birth details');
    }

    /**
     * AUTO-CREATE INITIAL GROWTH RECORD
     */
    $stmt = $conn->prepare("
        INSERT INTO child_details (
            child_id,
            child_height,
            child_weight
        ) VALUES (?, ?, ?)
    ");

    $stmt->bind_param(
        "idd",
        $childId,
        $birth['birth_length'],
        $birth['birth_weight']
    );

    $stmt->execute(); // optional, safe even if skipped

    $conn->commit();

    echo json_encode([
        'success' => true,
        'child_id' => $childId
    ]);

} catch (Exception $e) {
    $conn->rollback();

    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
