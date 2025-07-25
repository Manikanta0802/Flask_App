from flask import Flask, request, jsonify, render_template
# import pymysql # Old import
import psycopg2 # New import for PostgreSQL
import os

app = Flask(__name__)

db_host_env = os.getenv('DB_HOST')
if db_host_env:
    if ':' in db_host_env:
        host, port_str = db_host_env.split(':')
        port = int(port_str)
    else:
        host = db_host_env
        port = 5432 # Default PostgreSQL port
else:
    # Fallback for local testing or if env var is missing during dev
    host = 'localhost'
    port = 5432

def get_db_connection():
    """Establish a new database connection."""
    try:
        return psycopg2.connect(
            host=host,
            port=port,
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            dbname=os.getenv('DB_NAME') # 'dbname' for PostgreSQL, not 'database'
        )
    except psycopg2.Error as e: # Catch psycopg2 specific errors
        print(f"Error connecting to the database: {e}")
        return None

@app.route('/')
def home():
    return render_template('employee_index.html')

@app.route('/employee')
def employee_details():
    return render_template('employee_details.html')

@app.route('/api/employees', methods=['GET', 'POST'])
def employees():
    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        # Use connection.cursor() without parameters for default cursor, or specify cursor_factory for dicts
        cursor = connection.cursor() 
        if request.method == 'POST':
            data = request.json
            if not all(key in data for key in ['name', 'employee_id', 'email']):
                return jsonify({"error": "Missing required fields"}), 400

            # Use %s for parameter substitution with psycopg2
            cursor.execute("INSERT INTO employees (name, employee_id, email) VALUES (%s, %s, %s)",
                           (data['name'], data['employee_id'], data['email']))
            connection.commit()
            return jsonify({"status": "success", "message": "Employee added successfully!"})

        elif request.method == 'GET':
            cursor.execute("SELECT id, name, employee_id, email FROM employees")
            rows = cursor.fetchall()
            # PostgreSQL fetchall returns tuples, convert to dicts for JSON
            employees_list = []
            for row in rows:
                employees_list.append({
                    "id": row[0],
                    "name": row[1],
                    "employee_id": row[2],
                    "email": row[3]
                })
            return jsonify({"status": "success", "data": employees_list})
    except psycopg2.Error as e: # Catch psycopg2 specific errors
        connection.rollback() # Rollback on error
        return jsonify({"error": f"Database error: {e}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if connection: # Ensure connection is closed even if an error occurs during connection creation
            connection.close()

@app.route('/api/employees/<int:employee_id_to_delete>', methods=['DELETE'])
def delete_employee(employee_id_to_delete):
    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        cursor = connection.cursor()
        # Execute DELETE query using the primary key 'id'
        cursor.execute("DELETE FROM employees WHERE id = %s", (employee_id_to_delete,))
        connection.commit()

        if cursor.rowcount == 0:
            return jsonify({"error": "Employee not found or already deleted"}), 404
        else:
            return jsonify({"status": "success", "message": "Employee deleted successfully!"}), 200

    except psycopg2.Error as e:
        connection.rollback()
        return jsonify({"error": f"Database error: {e}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if connection:
            connection.close()

@app.route('/api/employees/<int:employee_id_to_fetch>', methods=['GET'])
def get_single_employee(employee_id_to_fetch):
    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        cursor = connection.cursor()
        cursor.execute("SELECT id, name, employee_id, email FROM employees WHERE id = %s", (employee_id_to_fetch,))
        row = cursor.fetchone()

        if row is None:
            return jsonify({"error": "Employee not found"}), 404
        else:
            employee_data = {
                "id": row[0],
                "name": row[1],
                "employee_id": row[2],
                "email": row[3]
            }
            return jsonify({"status": "success", "data": employee_data}), 200

    except psycopg2.Error as e:
        return jsonify({"error": f"Database error: {e}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if connection:
            connection.close()


@app.route('/api/employees/<int:employee_id_to_update>', methods=['PUT'])
def update_employee(employee_id_to_update):
    connection = get_db_connection()
    if not connection:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        data = request.json
        if not all(key in data for key in ['name', 'employee_id', 'email']):
            return jsonify({"error": "Missing required fields"}), 400

        cursor = connection.cursor()
        cursor.execute(
            "UPDATE employees SET name = %s, employee_id = %s, email = %s WHERE id = %s",
            (data['name'], data['employee_id'], data['email'], employee_id_to_update)
        )
        connection.commit()

        if cursor.rowcount == 0:
            return jsonify({"error": "Employee not found or no changes made"}), 404
        else:
            return jsonify({"status": "success", "message": "Employee updated successfully!"}), 200

    except psycopg2.Error as e:
        connection.rollback()
        return jsonify({"error": f"Database error: {e}"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        if connection:
            connection.close()

if __name__ == "__main__":
    # In production, use a WSGI server like Gunicorn. For this project's scope, Flask's built-in server is used.
    app.run(host="0.0.0.0", port=80)