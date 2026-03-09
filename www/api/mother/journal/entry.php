<?php
// api/mother/journal/entry.php
require_once '../../db.php';
header('Content-Type: application/json');

if (!isset($_GET['entry_id'], $_GET['mother_id'])) {
    echo json_encode([
        'success' => false,
        'message' => 'entry_id and mother_id required'
    ]);
    exit;
}

$entry_id = (int)$_GET['entry_id'];
$mother_id = (int)$_GET['mother_id'];
$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'PUT') {

    $data = json_decode(file_get_contents('php://input'), true);

    if (!isset($data['content'])) {
        echo json_encode([
            'success' => false,
            'message' => 'content required'
        ]);
        exit;
    }

    $title = $data['title'] ?? null;
    $content = $data['content'];

    $stmt = $conn->prepare(
        "UPDATE journal_entries
         SET title = ?, content = ?, updated_at = NOW()
         WHERE entry_id = ? AND mother_id = ?"
    );

    $stmt->bind_param('ssii', $title, $content, $entry_id, $mother_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Update failed',
            'error' => $stmt->error
        ]);
    }

    $stmt->close();
    exit;
}

if ($method === 'DELETE') {

    $stmt = $conn->prepare(
        "DELETE FROM journal_entries
         WHERE entry_id = ? AND mother_id = ?"
    );

    $stmt->bind_param('ii', $entry_id, $mother_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true]);
    } else {
        echo json_encode([
            'success' => false,
            'message' => 'Delete failed',
            'error' => $stmt->error
        ]);
    }

    $stmt->close();
    exit;
}

echo json_encode([
    'success' => false,
    'message' => 'Method not allowed'
]);
