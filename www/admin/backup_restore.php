<?php
session_start();

// Check if user is logged in and is an admin
if (!isset($_SESSION['account_id']) || ($_SESSION['account_type'] ?? '') !== 'admin') {
    header("Location: login.php");
    exit();
}

require_once __DIR__ . '/../api/db.php';

$message = '';
$error = '';

// Handle database backup
if (isset($_POST['backup'])) {
    try {
        $tables = [];
        if ($result = $conn->query("SHOW TABLES")) {
            while ($row = $result->fetch_row()) {
                $tables[] = $row[0];
            }
        }

        $output = '';

        foreach ($tables as $table) {
            // Table structure
            $output .= "--\n-- Table structure for table `$table`\n--\n";
            $output .= "DROP TABLE IF EXISTS `$table`;\n";
            $createRes = $conn->query("SHOW CREATE TABLE `$table`");
            $createRow = $createRes ? $createRes->fetch_row() : null;
            if (!$createRow) {
                throw new RuntimeException("Failed to read schema for {$table}");
            }
            $output .= $createRow[1] . ";\n\n";

            // Table data
            $output .= "--\n-- Dumping data for table `$table`\n--\n";
            $dataRes = $conn->query("SELECT * FROM `$table`");
            if ($dataRes) {
                while ($row = $dataRes->fetch_assoc()) {
                    $values = [];
                    foreach ($row as $value) {
                        if (is_null($value)) {
                            $values[] = 'NULL';
                        } else {
                            $values[] = "'" . $conn->real_escape_string($value) . "'";
                        }
                    }
                    $output .= "INSERT INTO `$table` VALUES(" . implode(',', $values) . ");\n";
                }
            }
            $output .= "\n";
        }

        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="inaagapay_backup_' . date('Y-m-d_H-i-s') . '.sql"');

        echo $output;
        exit();

    } catch (Throwable $e) {
        $error = "Error generating backup: " . $e->getMessage();
    }
}

// Handle database restore
if (isset($_FILES['import_file'])) {
    $file = $_FILES['import_file'];

    if ($file['error'] === UPLOAD_ERR_OK) {
        $fileInfo = pathinfo($file['name']);
        if (strtolower($fileInfo['extension'] ?? '') === 'sql') {
            $sql = file_get_contents($file['tmp_name']);

            $conn->query("SET FOREIGN_KEY_CHECKS=0");

            if ($conn->multi_query($sql)) {
                do {
                    if ($result = $conn->store_result()) {
                        $result->free();
                    }
                } while ($conn->more_results() && $conn->next_result());

                $message = "Database restored successfully!";

                $stmt = $conn->prepare("INSERT INTO audit_trail (account_id, action, description, ip_address) VALUES (?, 'database_restore', ?, ?)");
                if ($stmt) {
                    $desc = $message;
                    $ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    $stmt->bind_param('iss', $_SESSION['account_id'], $desc, $ip);
                    $stmt->execute();
                }
            } else {
                $error = "Error restoring database: " . $conn->error;
            }

            $conn->query("SET FOREIGN_KEY_CHECKS=1");
        } else {
            $error = "Please upload a valid SQL file.";
        }
    } else {
        $error = "Error uploading file. Please try again.";
    }
}
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Backup - InaAgapay Admin</title>
    <link rel="stylesheet" href="../styles/header_navbar.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css">
    <style>
        :root {
            --primary-color: #ec407a;
            --primary-dark: #d81b60;
            --secondary-color: #ff9eb7;
            --gray-dark: #3f3d56;
            --gray-light: #fff5fb;
            --gray: #e5d6df;
            --border: #f0c6d8;
        }

        body {
            background: radial-gradient(circle at 20% 20%, #ffeef6, #ffffff 35%),
                radial-gradient(circle at 80% 0%, #fff5fb, #ffffff 40%);
            margin: 0;
            font-family: 'Poppins', 'Segoe UI', sans-serif;
        }

        .backup-container {
            max-width: 800px;
            margin: 2rem auto;
            padding: 2rem;
            background: white;
            border-radius: 10px;
            border: 1px solid var(--border);
            box-shadow: 0 12px 40px rgba(236, 64, 122, 0.12);
        }

        .backup-header {
            text-align: center;
            margin-bottom: 2rem;
            color: var(--primary-color);
        }

        .backup-header h1 {
            font-size: 2rem;
            margin-bottom: 0.5rem;
        }

        .backup-header p {
            color: var(--gray-dark);
        }

        .backup-section {
            background: var(--gray-light);
            padding: 2rem;
            border-radius: 8px;
            margin-bottom: 2rem;
        }

        .backup-section h2 {
            color: var(--primary-color);
            margin-bottom: 1rem;
            font-size: 1.5rem;
        }

        .backup-section p {
            margin-bottom: 1.5rem;
            color: var(--gray-dark);
        }

        .file-upload {
            display: flex;
            align-items: center;
            gap: 1rem;
            margin-bottom: 1rem;
        }

        .file-upload input[type="file"] {
            flex: 1;
            padding: 0.5rem;
            border: 1px solid var(--gray);
            border-radius: 4px;
        }

        .success-message {
            background-color: #d4edda;
            color: #155724;
            padding: 1rem;
            border-radius: 4px;
            margin-bottom: 1rem;
        }

        .error-message {
            background-color: #f8d7da;
            color: #721c24;
            padding: 1rem;
            border-radius: 4px;
            margin-bottom: 1rem;
        }

        .btn-backup {
            background: var(--primary-color);
            color: white;
            padding: 0.8rem 1.5rem;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 1rem;
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
            transition: all 0.3s ease;
        }

        .btn-backup:hover {
            background: var(--primary-dark);
            transform: translateY(-2px);
        }

        .btn-import {
            background: var(--secondary-color);
        }

        .btn-import:hover {
            background: #455a64;
        }
    </style>
</head>

<body>
    <?php include 'header_navbar.php'; ?>

    <main class="main-content" id="mainContent">
        <div class="content">
            <div class="backup-container">
                <div class="backup-header">
                    <h1><i class="fas fa-database"></i> Database Backup</h1>
                    <p>Manage your database backups and restores</p>
                </div>

                <?php if (!empty($message)): ?>
                    <div class="success-message">
                        <i class="fas fa-check-circle"></i>
                        <?php echo $message; ?>
                    </div>
                <?php endif; ?>

                <?php if (!empty($error)): ?>
                    <div class="error-message">
                        <i class="fas fa-exclamation-circle"></i>
                        <?php echo $error; ?>
                    </div>
                <?php endif; ?>

                <div class="backup-section">
                    <h2><i class="fas fa-download"></i> Backup Database</h2>
                    <p>Download a complete backup of your database. This file can be used to restore your data later.
                    </p>
                    <form method="post">
                        <button type="submit" name="backup" class="btn-backup">
                            <i class="fas fa-download"></i> Download Backup
                        </button>
                    </form>
                </div>

                <div class="backup-section">
                    <h2><i class="fas fa-upload"></i> Restore Database</h2>
                    <p>Import a previously created backup file to restore your database. Warning: This will overwrite
                        existing data.</p>
                    <form method="post" enctype="multipart/form-data">
                        <div class="file-upload">
                            <input type="file" name="import_file" accept=".sql" required>
                            <button type="submit" class="btn-backup btn-import">
                                <i class="fas fa-upload"></i> Import Backup
                            </button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
    </main>

    <script>
        // Confirm before importing
        document.querySelector('form[enctype="multipart/form-data"]').onsubmit = function (e) {
            if (!confirm('Warning: This will overwrite your existing database. Are you sure you want to proceed?')) {
                e.preventDefault();
            }
        };
    </script>
</body>

</html>