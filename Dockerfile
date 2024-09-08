

# Use the official Python base image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Copy the requirements file into the container
COPY engine_bet/requirements.txt .

# Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
COPY . .

# Copy the .env file into the container
COPY .env .

# Set environment variables from .env file
RUN export $(cat .env | xargs)

EXPOSE 8000

# Set the PYTHONPATH environment variable
ENV PYTHONPATH=/app

CMD ["uvicorn", "engine_bet.api.controller.view_bet:app", "--host", "0.0.0.0", "--port", "8000"]

# # COMANDS
# # docker-compose up --build
# # docker build -t engine_bet .
# # docker run -d -p 5001:8000 --name engine_bet_app engine_bet