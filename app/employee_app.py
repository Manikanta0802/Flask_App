import os

import psycopg2
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

# DB_HOST can come from Secrets Manager, for example:
# employees-db.c0y2x1y3z4a5.ap-south-1.rds.amazonaws.com:5432
db_host_env = os.getenv("DB_HOST")

if db_host_env:
    if ":" in db_host_env:
        host, port_str = db_host_env.split(":", 1)
        port = int(port_str)
    else:
        host = db_host_env
        port = 5432
else:
    # Fallback for local development.
    host = "localhost"
    port = 5432


def get_db_connection():
    """Establish a new database connection."""
    try:
        return psycopg2.connect(
            host=host,
            port=port,
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            dbname=os.getenv("DB_NAME"),
        )
    except psycopg2.Error as e:
        print(f"Error connecting to the database: {e}")
        return None


@app.route("/")
def home():
    return render_template("employee_index.html")


@app.route("/employee")
def employee_details():
    return render_template("employee_details.html")


@app.route("/api/employees", methods=["GET", "POST"])
def employees():
    connection = get_db_connection()

    if not connection:
        return jsonify({"error": "Database connection failed"}), 500

    try:
        with connection.cursor() as cursor:
            if request.method == "POST":
                data = request.get_json(silent=True)

                if not isinstance(data, dict):
                    return jsonify({"error": "Invalid request body"}), 400

                required_fields = ["name", "employee_id", "email"]

                if not all(key in data for key in required_fields):
                    return jsonify({"error": "Missing required fields"}), 400

                cursor.execute(
                    """
                    INSERT INTO employees (name, employee_id, email)
                    VALUES (%s, %s, %s)
                    """,
                    (data["name"], data["employee_id"], data["email"]),
                )

                connection.commit()

                return jsonify(
                    {
                        "status": "success",
                        "message": "Employee added successfully!",
                    }
                )

            if request.method == "GET":
                cursor.execute(
                    "SELECT id, name, employee_id, email FROM employees"
                )

                rows = cursor.fetchall()

                employees_list = []

                for row in rows:
                    employees_list.append(
                        {
                            "id": row[0],
                            "name": row[1],
                            "employee_id": row[2],
                            "email": row[3],
                        }
                    )

                return jsonify(
                    {
                        "status": "success",
                        "data": employees_list,
                    }
                )

    except psycopg2.Error as e:
        connection.rollback()

        return jsonify(
            {
                "error": f"Database error: {e}",
            }
        ), 500

    finally:
        connection.close()


if __name__ == "__main__":
    # Flask development server for local testing only.
    # Production should use Gunicorn or another WSGI server.
    app.run(host="127.0.0.1", port=5000)
