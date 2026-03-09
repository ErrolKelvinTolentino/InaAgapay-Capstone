<?php
require_once __DIR__ . '/../auth/auth_check.php';
header('Content-Type: application/json');

$pregnancyId = $_POST['pregnancy_id'] ?? null;
$date = $_POST['ultrasound_date'] ?? null;
$location = $_POST['ultrasound_location'] ?? null;
$remarks = $_POST['remarks'] ?? null;
$workerName = $_POST['health_worker_name'] ?? null;
$institution = $_POST['health_worker_institution'] ?? null;
$profession = $_POST['health_worker_profession'] ?? null;
$ultrasoundImage = null;

if (!$pregnancyId || !$date) {
    echo json_encode([
        'success' => false,
        'message' => 'Required fields missing'
    ]);
    exit;
}

$uploadField = 'ultrasound_image';
if (isset($_FILES[$uploadField]) && $_FILES[$uploadField]['error'] !== UPLOAD_ERR_NO_FILE) {
    if ($_FILES[$uploadField]['error'] !== UPLOAD_ERR_OK) {
        echo json_encode([
            'success' => false,
            'message' => 'Image upload failed'
        ]);
        exit;
    }

    $ext = strtolower(pathinfo($_FILES[$uploadField]['name'] ?? '', PATHINFO_EXTENSION));
    $allowed = ['jpg', 'jpeg', 'png', 'webp'];
    if (!in_array($ext, $allowed)) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid image type. Please upload JPG, PNG, or WebP.'
        ]);
        exit;
    }

    $uploadDir = __DIR__ . '/../../uploads/ultrasounds';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0775, true);
    }

    $filename = 'ultrasound_' . $pregnancyId . '_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
    $targetPath = $uploadDir . '/' . $filename;

    if (!move_uploaded_file($_FILES[$uploadField]['tmp_name'], $targetPath)) {
        echo json_encode([
            'success' => false,
            'message' => 'Failed to save image'
        ]);
        exit;
    }

    $ultrasoundImage = 'uploads/ultrasounds/' . $filename;
}

$stmt = $conn->prepare("
    INSERT INTO ultrasounds (
        pregnancy_id,
        ultrasound_date,
        ultrasound_location,
        ultrasound_image,
        remarks,
        health_worker_name,
        health_worker_institution,
        health_worker_profession
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
");

$stmt->bind_param(
    "isssssss",
    $pregnancyId,
    $date,
    $location,
    $ultrasoundImage,
    $remarks,
    $workerName,
    $institution,
    $profession
);

if ($stmt->execute()) {
    echo json_encode(['success' => true]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'Insert failed'
    ]);
}
