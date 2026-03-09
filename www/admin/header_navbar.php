<?php
// Start session safely
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Unified session model
$isLoggedIn = isset($_SESSION['account_id']);
$accountType = $_SESSION['account_type'] ?? null;
$username = $_SESSION['user_name'] ?? 'Guest';
$loginUrl = '/admin/login.php';
$logoutUrl = '/admin/logout.php';
?>

<header class="header">
    <div class="brand">
        <img src="images/logo_icon.png" class="logo" alt="InaAgapay Logo">
        <span class="brand-name">InaAgapay</span>
    </div>

    <nav class="top-nav">
        <?php if ($isLoggedIn && $accountType === 'admin'): ?>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'dashboard.php' ? 'active' : '' ?>"
                href="/admin/dashboard.php"><i class="fa-solid fa-gauge"></i><span>Dashboard</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'admin_account_management.php' ? 'active' : '' ?>"
                href="/admin/admin_account_management.php"><i class="fa-solid fa-users-cog"></i><span>Account
                    Management</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'midwife_assignment.php' ? 'active' : '' ?>"
                href="/admin/midwife_assignment.php"><i class="fa-solid fa-user-nurse"></i><span>Midwife
                    Assignment</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'admin_backup.php' ? 'active' : '' ?>"
                href="/admin/admin_backup.php"><i class="fa-solid fa-database"></i><span>Database Backup</span></a>
        <?php elseif ($isLoggedIn && $accountType === 'mother'): ?>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'mother_landing.php' ? 'active' : '' ?>"
                href="/mother/mother_landing.php"><i class="fa-solid fa-gauge"></i><span>Mother Dashboard</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'mother_pregnancy.php' ? 'active' : '' ?>"
                href="/mother/mother_pregnancy.php"><i class="fa-solid fa-baby"></i><span>Pregnancy</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'view_my_childrens.php' ? 'active' : '' ?>"
                href="/mother/view_my_childrens.php"><i class="fa-solid fa-children"></i><span>My Children</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'mother_journal.php' ? 'active' : '' ?>"
                href="/mother/mother_journal.php"><i class="fa-solid fa-book"></i><span>Pregnancy Journal</span></a>
        <?php elseif ($isLoggedIn && $accountType === 'midwife'): ?>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'midwife_landing.php' ? 'active' : '' ?>"
                href="/midwife/midwife_landing.php"><i class="fa-solid fa-gauge"></i><span>Midwife Dashboard</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'midwife_patients.php' ? 'active' : '' ?>"
                href="/midwife/midwife_patients.php"><i class="fa-solid fa-users"></i><span>Patients</span></a>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'midwife_checkup_schedules.php' ? 'active' : '' ?>"
                href="/midwife/midwife_checkup_schedules.php"><i
                    class="fa-solid fa-calendar-check"></i><span>Schedules</span></a>
        <?php else: ?>
            <a class="<?= basename($_SERVER['PHP_SELF']) === 'index.php' ? 'active' : '' ?>" href="/index.php"><i
                    class="fa-solid fa-house"></i><span>Home</span></a>
        <?php endif; ?>
    </nav>

    <div class="user-actions">
        <div class="user-info">
            <div class="user-avatar">
                <i class="fa-solid fa-user"></i>
            </div>
            <span><?= htmlspecialchars($username) ?></span>
            <?php if ($isLoggedIn && $accountType): ?>
                <span class="account-type-label">(<?= ucfirst($accountType) ?>)</span>
            <?php endif; ?>
        </div>

        <?php if ($isLoggedIn): ?>
            <button class="logout-btn" onclick="confirmLogout()">
                <i class="fa-solid fa-right-from-bracket"></i> Logout
            </button>
        <?php else: ?>
            <button class="logout-btn" onclick="location.href='<?= $loginUrl ?>'">
                <i class="fa-solid fa-right-to-bracket"></i> Login
            </button>
        <?php endif; ?>
    </div>
</header>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
    function confirmLogout() {
        Swal.fire({
            title: 'Logout?',
            text: 'You will be logged out.',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonText: 'Logout'
        }).then(res => {
            if (res.isConfirmed) location.href = '<?= $logoutUrl ?>';
        });
    }
</script>