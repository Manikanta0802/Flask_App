<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Employee Details</title>
    <style>
        body {
            background-image: url('https://img.freepik.com/free-photo/notebook-glasses-crop-laptop-near-coffee_23-2147777915.jpg?t=st=1732718576~exp=1732722176~hmac=b890b12010d6f9c03110799b3e75aedc153da6ee610b4c17e029313b0592cc33&w=1380'); /* Replace with your image URL */
            background-size: cover;
            background-position: center;
            height: 100vh; /* Make sure the background covers the full height */
            margin: 0;
            font-family: Arial, sans-serif;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            color: red; /* Adjust text color for readability on background */
        }

        .container {
            width: 80%;
            max-width: 1200px;
            margin: 20px;
            background-color: #fff;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }

        h1 {
            margin-top: 20px;
            font-size: 2.5em;
            color: #333;
        }

        table {
            width: 100%;
            margin: 20px 0;
            border-collapse: collapse;
            background-color: #f9f9f9;
            box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
        }

        th, td {
            padding: 12px;
            text-align: center;
            border: 1px solid #ddd;
            color: black; /* Ensure text is visible in table */
        }

        th {
            background-color: #007BFF;
            color: white;
        }

        tr:nth-child(even) {
            background-color: #f2f2f2;
        }

        tr:hover {
            background-color: #ddd;
        }

        a {
            display: inline-block;
            margin-top: 20px;
            padding: 10px 20px;
            background-color: #007BFF;
            color: white;
            text-decoration: none;
            border-radius: 5px;
        }

        a:hover {
            background-color: #0056b3;
        }

        .action-btn {
            background-color: #28a745; /* Green for edit */
            color: white;
            border: none;
            padding: 8px 12px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 0.9em;
            margin: 0 5px;
        }

        .action-btn.delete-btn {
            background-color: #dc3545; /* Red for delete */
        }

        .action-btn:hover {
            opacity: 0.9;
        }

        /* Modal Styles */
        .modal {
            display: none; /* Hidden by default */
            position: fixed; /* Stay in place */
            z-index: 1; /* Sit on top */
            left: 0;
            top: 0;
            width: 100%; /* Full width */
            height: 100%; /* Full height */
            overflow: auto; /* Enable scroll if needed */
            background-color: rgba(0,0,0,0.4); /* Black w/ opacity */
            justify-content: center;
            align-items: center;
        }

        .modal-content {
            background-color: #fefefe;
            margin: auto;
            padding: 20px;
            border: 1px solid #888;
            width: 80%;
            max-width: 500px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
            position: relative;
            color: black; /* Ensure text is visible in modal */
        }

        .close-button {
            color: #aaa;
            float: right;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
        }

        .close-button:hover,
        .close-button:focus {
            color: black;
            text-decoration: none;
            cursor: pointer;
        }

        .modal-content input {
            width: calc(100% - 22px); /* Adjust for padding and border */
            margin-bottom: 15px;
        }

        .modal-content button {
            width: 100%;
            padding: 10px;
            background-color: #007BFF;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1em;
        }

        .modal-content button:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Employee Details</h1>
        <table>
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Employee ID</th>
                    <th>Email</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody id="employeeTable"></tbody>
        </table>
        <a href="/">Back to Dashboard</a>
    </div>

    <!-- Edit Employee Modal -->
    <div id="editEmployeeModal" class="modal">
        <div class="modal-content">
            <span class="close-button" onclick="closeEditModal()">&times;</span>
            <h2>Edit Employee</h2>
            <input type="hidden" id="editEmployeeId"> <!-- Hidden field to store the DB ID -->
            <input type="text" id="editName" placeholder="Name">
            <input type="text" id="editEmployee_id" placeholder="Employee ID">
            <input type="email" id="editEmail" placeholder="Email">
            <button onclick="saveEmployeeChanges()">Save Changes</button>
        </div>
    </div>

    <script>
        // Function to fetch and display employees
        async function fetchEmployees() {
            const response = await fetch('/api/employees');
            const employees = await response.json();

            const employeeTableBody = document.getElementById('employeeTable');
            employeeTableBody.innerHTML = ''; // Clear existing rows

            if (employees.status === 'success' && employees.data && employees.data.length > 0) {
                employees.data.forEach(emp => {
                    const row = document.createElement('tr');
                    row.innerHTML = `
                        <td>${emp.name}</td>
                        <td>${emp.employee_id}</td>
                        <td>${emp.email}</td>
                        <td>
                            <button class="action-btn" onclick="editEmployee(${emp.id})">Edit</button>
                            <button class="action-btn delete-btn" onclick="deleteEmployee(${emp.id})">Delete</button>
                        </td>
                    `;
                    employeeTableBody.appendChild(row);
                });
            } else {
                employeeTableBody.innerHTML = '<tr><td colspan="4">No employees found.</td></tr>';
            }
        }

        // Function to handle deletion
        async function deleteEmployee(employeeId) {
            if (!confirm(`Are you sure you want to delete employee with ID: ${employeeId}?`)) {
                return; // User cancelled the deletion
            }

            try {
                const response = await fetch(`/api/employees/${employeeId}`, {
                    method: 'DELETE',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                });

                const result = await response.json();

                if (response.ok) {
                    alert('Employee deleted successfully!');
                    fetchEmployees(); // Refresh the table after deletion
                } else {
                    alert('Error: ' + result.error);
                }
            } catch (error) {
                alert('Error: ' + error.message);
            }
        }

        // --- NEW JAVASCRIPT FUNCTIONS FOR EDITING ---

        // Function to open the modal and populate it with employee data
        async function editEmployee(employeeId) {
            try {
                const response = await fetch(`/api/employees/${employeeId}`);
                const result = await response.json();

                if (response.ok && result.status === 'success') {
                    const employee = result.data;
                    document.getElementById('editEmployeeId').value = employee.id;
                    document.getElementById('editName').value = employee.name;
                    document.getElementById('editEmployee_id').value = employee.employee_id;
                    document.getElementById('editEmail').value = employee.email;

                    document.getElementById('editEmployeeModal').style.display = 'flex'; // Show modal
                } else {
                    alert('Error fetching employee data: ' + result.error);
                }
            } catch (error) {
                alert('Error: ' + error.message);
            }
        }

        // Function to close the modal
        function closeEditModal() {
            document.getElementById('editEmployeeModal').style.display = 'none';
        }

        // Function to save changes to an employee
        async function saveEmployeeChanges() {
            const id = document.getElementById('editEmployeeId').value;
            const name = document.getElementById('editName').value;
            const employee_id = document.getElementById('editEmployee_id').value;
            const email = document.getElementById('editEmail').value;

            if (!name || !employee_id || !email) {
                alert('Please fill in all fields');
                return;
            }

            const data = { name, employee_id, email };

            try {
                const response = await fetch(`/api/employees/${id}`, {
                    method: 'PUT',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(data)
                });

                const result = await response.json();

                if (response.ok) {
                    alert('Employee updated successfully!');
                    closeEditModal(); // Close modal
                    fetchEmployees(); // Refresh the table
                } else {
                    alert('Error updating employee: ' + result.error);
                }
            } catch (error) {
                alert('Error: ' + error.message);
            }
        }

        // Call on page load
        fetchEmployees();
    </script>
</body>
</html>