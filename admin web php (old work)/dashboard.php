<?php
session_start();
// Redirect to login if not logged in or not admin
if (!isset($_SESSION['account_id']) || ($_SESSION['account_type'] ?? '') !== 'admin') {
    header('Location: login.php');
    exit();
}
require_once __DIR__ . '/../api/db.php';

// Fetch quick statistics using MySQLi
$stats = [];

function fetch_single_count($conn, $sql)
{
    $res = $conn->query($sql);
    if ($res && ($row = $res->fetch_row())) {
        return (int) $row[0];
    }
    return 0;
}

$stats['mothers'] = fetch_single_count($conn, "SELECT COUNT(*) FROM accounts WHERE account_type = 'mother' AND status = 'active'");
$stats['midwives'] = fetch_single_count($conn, "SELECT COUNT(*) FROM accounts WHERE account_type = 'midwife' AND status = 'active'");
$stats['pregnancies'] = fetch_single_count($conn, "SELECT COUNT(*) FROM pregnancies");
$stats['children'] = fetch_single_count($conn, "SELECT COUNT(*) FROM children");

// Risk distribution for pregnancies
$riskData = [];
if ($res = $conn->query("SELECT pregnancy_risk_level, COUNT(*) AS c FROM pregnancies GROUP BY pregnancy_risk_level")) {
    while ($row = $res->fetch_assoc()) {
        $riskData[$row['pregnancy_risk_level'] ?? 'unknown'] = (int) $row['c'];
    }
}

// Midwives per BHC
$bhcMidwives = [];
$bhcRes = $conn->query("SELECT b.bhc_name, COUNT(m.midwife_id) AS c FROM bhc b LEFT JOIN midwives m ON b.bhc_id = m.assigned_bhc_id GROUP BY b.bhc_id ORDER BY b.bhc_name");
while ($row = $bhcRes->fetch_assoc()) {
    $bhcMidwives[] = $row;
}

// Pregnancies created per month (last 6 months)
$monthly = [];
$monthlyRes = $conn->query("SELECT DATE_FORMAT(created_at, '%Y-%m') AS ym, COUNT(*) AS c FROM pregnancies WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH) GROUP BY ym ORDER BY ym");
while ($row = $monthlyRes->fetch_assoc()) {
    $monthly[] = $row;
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard - InaAgapay</title>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="stylesheet" href="../styles/header_navbar.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/sweetalert2@11/dist/sweetalert2.min.css">
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap"
        rel="stylesheet">
    <style>
        :root {
            --primary-color: #ec407a;
            --secondary-color: #ff9eb7;
            --accent-color: #ff4d7e;
            --light-bg: #fff5f7;
            --dark-bg: #4a2a36;
            --success-color: #a8e6cf;
            --info-color: #dcedc1;
            --warning-color: #ffd3b6;
            --danger-color: #ffaaa5;
            --border: #f0c6d8;
        }

        body {
            font-family: 'Poppins', sans-serif;
            background: radial-gradient(circle at 20% 20%, #ffeef6, #ffffff 35%),
                radial-gradient(circle at 80% 0%, #fff5fb, #ffffff 40%);
            color: #4a2a36;
        }

        main.main-content {
            min-height: calc(100vh - var(--nav-height));
            padding: 24px;
            padding-top: calc(var(--nav-height) + 16px);
        }

        .welcome-banner {
            background: linear-gradient(135deg, var(--primary-color), var(--accent-color));
            border-radius: 15px;
            padding: 2.5rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(255, 107, 154, 0.3);
            position: relative;
            overflow: hidden;
        }

        .welcome-banner::before {
            content: '';
            position: absolute;
            top: -50px;
            right: -50px;
            width: 200px;
            height: 200px;
            background: rgba(255, 255, 255, 0.15);
            border-radius: 50%;
        }

        .welcome-banner::after {
            content: '';
            position: absolute;
            bottom: -30px;
            right: 100px;
            width: 150px;
            height: 150px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 50%;
        }

        .welcome-title {
            font-weight: 700;
            color: white;
            margin-bottom: 1rem;
            position: relative;
            z-index: 1;
            text-shadow: 1px 1px 3px rgba(0, 0, 0, 0.2);
        }

        .welcome-title i {
            margin-right: 15px;
            font-size: 1.5em;
            vertical-align: middle;
        }

        .admin-stats {
            display: flex;
            flex-wrap: wrap;
            gap: 15px;
            margin-top: 2rem;
            position: relative;
            z-index: 1;
        }

        .stat-badge {
            background: rgba(255, 255, 255, 0.25);
            backdrop-filter: blur(5px);
            border-radius: 10px;
            padding: 15px 20px;
            display: flex;
            align-items: center;
            gap: 10px;
            color: white;
            font-weight: 500;
            transition: all 0.3s ease;
            border: 1px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.1);
        }

        .stat-badge:hover {
            background: rgba(255, 255, 255, 0.35);
            transform: translateY(-3px);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.15);
        }

        .stat-badge i {
            font-size: 1.5rem;
            color: white;
        }

        .floating {
            animation: float 6s ease-in-out infinite;
            filter: drop-shadow(0 10px 15px rgba(0, 0, 0, 0.2));
            position: relative;
            z-index: 1;
        }

        @keyframes float {
            0% {
                transform: translateY(0px);
            }

            50% {
                transform: translateY(-15px);
            }

            100% {
                transform: translateY(0px);
            }
        }

        .action-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-top: 2rem;
        }

        .action-card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            text-align: center;
            transition: all 0.3s ease;
            box-shadow: 0 5px 15px rgba(0, 0, 0, 0.05);
            border: none;
            text-decoration: none;
            color: inherit;
            position: relative;
            overflow: hidden;
            border-left: 5px solid var(--primary-color);
        }

        .action-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(255, 107, 154, 0.2);
            color: var(--accent-color);
        }

        .action-card i {
            font-size: 2.5rem;
            margin-bottom: 1rem;
            color: var(--primary-color);
            transition: all 0.3s ease;
        }

        .action-card:hover i {
            transform: scale(1.1);
        }

        .action-card h3 {
            font-weight: 600;
            margin-bottom: 0.5rem;
            color: var(--dark-bg);
        }

        .action-card p {
            color: #6c757d;
            font-size: 0.9rem;
            margin-bottom: 0;
        }

        .action-card:nth-child(1) {
            border-left-color: var(--primary-color);
        }

        .action-card:nth-child(1) i {
            color: var(--primary-color);
        }

        .action-card:nth-child(2) {
            border-left-color: var(--secondary-color);
        }

        .action-card:nth-child(2) i {
            color: var(--secondary-color);
        }

        .action-card:nth-child(3) {
            border-left-color: var(--success-color);
        }

        .action-card:nth-child(3) i {
            color: var(--success-color);
        }

        .action-card:nth-child(4) {
            border-left-color: var(--info-color);
        }

        .action-card:nth-child(4) i {
            color: var(--info-color);
        }

        .section-title {
            font-weight: 600;
            color: var(--dark-bg);
            margin-bottom: 1.5rem;
            position: relative;
            padding-bottom: 10px;
        }

        .section-title::after {
            content: '';
            position: absolute;
            left: 0;
            bottom: 0;
            width: 50px;
            height: 3px;
            background: var(--primary-color);
            border-radius: 3px;
        }

        @media (max-width: 768px) {
            .welcome-banner {
                padding: 1.5rem;
            }

            .admin-stats {
                gap: 10px;
            }

            .stat-badge {
                padding: 10px 15px;
                font-size: 0.9rem;
            }

            .action-cards {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>

<body>
    <?php include __DIR__ . '/header_navbar.php'; ?>
    <main class="main-content" id="mainContent">
        <div class="container py-4">
            <div class="welcome-banner">
                <div class="row align-items-center">
                    <div class="col-md-8">
                        <h1 class="welcome-title">
                            <i class="fas fa-user-shield"></i>
                            Welcome, <?php echo htmlspecialchars($_SESSION['user_name']); ?>!
                        </h1>
                        <p class="text-white mb-0" style="opacity: 0.9; text-shadow: 1px 1px 2px rgba(0,0,0,0.2);">
                            Manage
                            and monitor the InaAgapay system efficiently.</p>

                        <div class="admin-stats">
                            <div class="stat-badge">
                                <i class="fas fa-female"></i>
                                <span><?php echo number_format($stats['mothers']); ?> Mothers</span>
                            </div>
                            <div class="stat-badge">
                                <i class="fas fa-user-nurse"></i>
                                <span><?php echo number_format($stats['midwives']); ?> Midwives</span>
                            </div>
                            <div class="stat-badge">
                                <i class="fas fa-baby-carriage"></i>
                                <span><?php echo number_format($stats['pregnancies']); ?> Pregnancies</span>
                            </div>
                            <div class="stat-badge">
                                <i class="fas fa-baby"></i>
                                <span><?php echo number_format($stats['children']); ?> Children</span>
                            </div>
                        </div>
                    </div>
                    <div class="col-md-4 text-center">
                        <img src="https://cdn-icons-png.flaticon.com/512/1802/1802977.png" alt="Admin Dashboard"
                            class="img-fluid floating" style="max-height: 180px;">
                    </div>
                </div>
            </div>

            <h3 class="section-title">Quick Actions</h3>

            <div class="action-cards">
                <a href="admin_account_management.php" class="action-card">
                    <i class="fas fa-users-cog"></i>
                    <h3>Account Management</h3>
                    <p>Manage user accounts, roles, and permissions</p>
                </a>

                <a href="admin_account_creation.php" class="action-card">
                    <i class="fas fa-user-plus"></i>
                    <h3>Create Account</h3>
                    <p>Add new midwife or administrator accounts</p>
                </a>

                <a href="admin_audit_trail.php" class="action-card">
                    <i class="fas fa-history"></i>
                    <h3>Audit Trail</h3>
                    <p>View system activity logs and user actions</p>
                </a>

                <a href="admin_backup.php" class="action-card">
                    <i class="fas fa-database"></i>
                    <h3>Database Backup</h3>
                    <p>Manage system backups and restoration</p>
                </a>
            </div>

            <h3 class="section-title mt-4">Insights</h3>
            <div class="row g-4">
                <div class="col-lg-6">
                    <div class="card p-3 h-100">
                        <h5 class="mb-3">Pregnancy Risk Distribution</h5>
                        <canvas id="riskChart"></canvas>
                    </div>
                </div>
                <div class="col-lg-6">
                    <div class="card p-3 h-100">
                        <h5 class="mb-3">Midwives per BHC</h5>
                        <canvas id="bhcChart"></canvas>
                    </div>
                </div>
                <div class="col-12">
                    <div class="card p-3 h-100">
                        <h5 class="mb-3">New Pregnancies (Last 6 Months)</h5>
                        <canvas id="monthlyChart"></canvas>
                    </div>
                </div>
            </div>
        </div>
    </main>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        // Add animation to stat badges on page load
        document.addEventListener('DOMContentLoaded', function () {
            const statBadges = document.querySelectorAll('.stat-badge');
            statBadges.forEach((badge, index) => {
                setTimeout(() => {
                    badge.style.opacity = '1';
                    badge.style.transform = 'translateY(0)';
                }, index * 150);
            });
        });

        // Charts data from PHP
        const riskLabels = <?= json_encode(array_keys($riskData)) ?>;
        const riskValues = <?= json_encode(array_values($riskData)) ?>;
        new Chart(document.getElementById('riskChart'), {
            type: 'doughnut',
            data: { labels: riskLabels, datasets: [{ data: riskValues, backgroundColor: ['#66bb6a', '#ffa726', '#ef5350', '#b0bec5'] }] },
            options: { plugins: { legend: { position: 'bottom' } } }
        });

        const bhcLabels = <?= json_encode(array_column($bhcMidwives, 'bhc_name')) ?>;
        const bhcValues = <?= json_encode(array_map('intval', array_column($bhcMidwives, 'c'))) ?>;
        new Chart(document.getElementById('bhcChart'), {
            type: 'bar',
            data: { labels: bhcLabels, datasets: [{ label: 'Midwives', data: bhcValues, backgroundColor: '#ec407a' }] },
            options: { scales: { y: { beginAtZero: true } } }
        });

        const monthlyLabels = <?= json_encode(array_column($monthly, 'ym')) ?>;
        const monthlyValues = <?= json_encode(array_map('intval', array_column($monthly, 'c'))) ?>;
        new Chart(document.getElementById('monthlyChart'), {
            type: 'line',
            data: { labels: monthlyLabels, datasets: [{ label: 'Pregnancies', data: monthlyValues, fill: false, borderColor: '#29b6f6', tension: 0.2 }] },
            options: { scales: { y: { beginAtZero: true } } }
        });
    </script>
</body>

</html>