# Use a lightweight official Python image as the base
FROM python:3.8-slim-buster

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file and install dependencies
# This step is cached, so if requirements don't change, it's faster
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the main application file
COPY employee_app.py .

# Create the 'templates' directory inside the container
RUN mkdir -p templates

# Copy individual HTML files into the 'templates' directory inside the container
# ASSUMPTION: employee_index.html and employee_details.html are in the root of your Git repo
COPY employee_index.html templates/
COPY employee_details.html templates/

# Expose the port that Gunicorn will listen on
EXPOSE 8000

# Set environment variables for the application
ENV DB_HOST="dummy_host" \
    DB_USER="dummy_user" \
    DB_PASSWORD="dummy_password" \
    DB_NAME="dummy_db" \
    FLASK_APP="employee_app.py"

# Command to run the application using Gunicorn
CMD ["gunicorn", "--workers", "4", "--bind", "0.0.0.0:8000", "employee_app:app"]
