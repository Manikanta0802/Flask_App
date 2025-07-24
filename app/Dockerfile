FROM python:3.8-slim-buster

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


COPY employee_app.py .

RUN mkdir -p templates

COPY employee_index.html templates/
COPY employee_details.html templates/

EXPOSE 8000

# Set environment variables for the application
ENV DB_HOST="dummy_host" \
    DB_USER="dummy_user" \
    DB_PASSWORD="dummy_password" \
    DB_NAME="dummy_db" \
    FLASK_APP="employee_app.py"

# Command to run the application using Gunicorn
CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:8000", "employee_app:app"]
