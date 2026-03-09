<?php
session_start();
require_once __DIR__ . '/../api/db.php';

if (!isset($_SESSION['account_id']) || ($_SESSION['account_type'] ?? '') !== 'admin') {
	header('Location: login.php');
	exit;
}

$message = '';
$error = '';

// Handle assignment updates
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	$accountId = (int) ($_POST['account_id'] ?? 0);
	$bhcId = (int) ($_POST['bhc_id'] ?? 0);
	if ($accountId && $bhcId) {
		try {
			$check = $conn->prepare('SELECT midwife_id FROM midwives WHERE account_id = ?');
			$check->bind_param('i', $accountId);
			$check->execute();
			$res = $check->get_result();
			if ($res->num_rows) {
				$update = $conn->prepare('UPDATE midwives SET assigned_bhc_id = ? WHERE account_id = ?');
				$update->bind_param('ii', $bhcId, $accountId);
				$update->execute();
			} else {
				$insert = $conn->prepare('INSERT INTO midwives (account_id, assigned_bhc_id) VALUES (?, ?)');
				$insert->bind_param('ii', $accountId, $bhcId);
				$insert->execute();
			}
			$message = 'Assignment updated successfully.';
		} catch (Throwable $e) {
			$error = 'Failed to update assignment: ' . $e->getMessage();
		}
	} else {
		$error = 'Please select both a midwife and a BHC.';
	}
}

// Fetch BHC list
$bhc = [];
if ($res = $conn->query('SELECT bhc_id, bhc_name FROM bhc ORDER BY bhc_name')) {
	while ($row = $res->fetch_assoc()) {
		$bhc[] = $row;
	}
}

// Fetch midwives and current assignments
$midwives = [];
$midwifeQuery = $conn->query('SELECT a.account_id, a.first_name, a.last_name, a.email_address, m.assigned_bhc_id, m.midwife_id FROM accounts a LEFT JOIN midwives m ON a.account_id = m.account_id WHERE a.account_type = "midwife" AND a.status = "active" ORDER BY a.first_name');
while ($row = $midwifeQuery->fetch_assoc()) {
	$midwives[] = $row;
}
?>
<!DOCTYPE html>
<html lang="en">

<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Midwife Assignment - InaAgapay</title>
	<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css">
	<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
	<link rel="stylesheet" href="../styles/header_navbar.css">
	<style>
		body {
			background: #f6f8fb;
			font-family: 'Poppins', 'Segoe UI', sans-serif;
		}

		.page-header {
			display: flex;
			align-items: center;
			justify-content: space-between;
			gap: 12px;
			margin-bottom: 18px;
		}

		.card {
			border: none;
			border-radius: 16px;
			box-shadow: 0 12px 40px rgba(15, 23, 42, 0.08);
		}
	</style>
</head>

<body>
	<?php include __DIR__ . '/header_navbar.php'; ?>

	<main class="main-content" id="mainContent">
		<div class="container py-4">
			<div class="page-header">
				<h4 class="m-0">Assign Midwives</h4>
			</div>

			<?php if ($message): ?>
				<div class="alert alert-success"><?= htmlspecialchars($message) ?></div><?php endif; ?>
			<?php if ($error): ?>
				<div class="alert alert-danger"><?= htmlspecialchars($error) ?></div><?php endif; ?>

			<div class="card">
				<div class="card-body">
					<div class="table-responsive">
						<table class="table align-middle mb-0">
							<thead>
								<tr>
									<th>Midwife</th>
									<th>Email</th>
									<th>Assigned BHC</th>
									<th class="text-end">Status</th>
								</tr>
							</thead>
							<tbody>
								<?php foreach ($midwives as $m): ?>
									<tr>
										<td class="fw-semibold">
											<?= htmlspecialchars($m['first_name'] . ' ' . $m['last_name']) ?>
										</td>
										<td><?= htmlspecialchars($m['email_address']) ?></td>
										<td>
											<form method="post" class="row g-2 align-items-center">
												<input type="hidden" name="account_id"
													value="<?= (int) $m['account_id'] ?>">
												<div class="col-auto" style="min-width:220px;">
													<select name="bhc_id" class="form-select form-select-sm" required>
														<option value="">Select BHC</option>
														<?php foreach ($bhc as $b): ?>
															<option value="<?= (int) $b['bhc_id'] ?>" <?= ((int) $m['assigned_bhc_id'] === (int) $b['bhc_id']) ? 'selected' : '' ?>>
																<?= htmlspecialchars($b['bhc_name']) ?>
															</option>
														<?php endforeach; ?>
													</select>
												</div>
												<div class="col-auto">
													<button type="submit" class="btn btn-primary btn-sm">Save</button>
												</div>
											</form>
										</td>
										<td class="text-end">
											<?php if ($m['assigned_bhc_id']): ?>
												<span class="badge bg-success bg-opacity-25 text-success">Assigned</span>
											<?php else: ?>
												<span class="badge bg-warning bg-opacity-25 text-warning">Unassigned</span>
											<?php endif; ?>
										</td>
									</tr>
								<?php endforeach; ?>
							</tbody>
						</table>
					</div>
				</div>
			</div>
		</div>
	</main>
</body>

</html>