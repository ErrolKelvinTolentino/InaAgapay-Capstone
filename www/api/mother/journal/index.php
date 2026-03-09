<?php
// api/mother/journal/index.php
require_once '../../db.php';
header('Content-Type: application/json');

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'POST') {

    $data = json_decode(file_get_contents('php://input'), true);

    if (
        !isset($data['mother_id']) ||
        !isset($data['content'])
    ) {
        echo json_encode([
            'success' => false,
            'message' => 'mother_id and content are required',
            'received' => $data
        ]);
        exit;
    }

    $mother_id = (int)$data['mother_id'];
    $title = $data['title'] ?? null;
    $content = $data['content'];

    $stmt = $conn->prepare(
        "INSERT INTO journal_entries (mother_id, title, content)
         VALUES (?, ?, ?)"
    );

    if (!$stmt) {
        echo json_encode([
            'success' => false,
            'message' => 'Prepare failed',
            'error' => $conn->error
        ]);
        exit;
    }

    $stmt->bind_param('iss', $mother_id, $title, $content);

    if ($stmt->execute()) {
        echo json_encode([
            'success' => true,
            'entry_id' => $stmt->insert_id
        ]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Insert failed',
            'error' => $stmt->error
        ]);
    }

    $stmt->close();
    exit;
}

if ($method === 'GET') {

    if (!isset($_GET['mother_id'])) {
        echo json_encode([
            'success' => false,
            'message' => 'mother_id required'
        ]);
        exit;
    }

    $mother_id = (int)$_GET['mother_id'];

    $stmt = $conn->prepare(
        "SELECT entry_id, title, content, created_at
         FROM journal_entries
         WHERE mother_id = ?
         ORDER BY created_at DESC"
    );

    $stmt->bind_param('i', $mother_id);
    $stmt->execute();
    $result = $stmt->get_result();

    echo json_encode($result->fetch_all(MYSQLI_ASSOC));
    $stmt->close();
    exit;
}

echo json_encode([
    'success' => false,
    'message' => 'Method not allowed'
]);
