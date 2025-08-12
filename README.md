# Saga Pattern Microservices

![CircleCI](https://img.shields.io/circleci/build/github/uuhnaut69/saga-pattern-microservices/master?color=green&logo=circleci&style=for-the-badge)
![Maven Central](https://img.shields.io/maven-central/v/org.springframework.boot/spring-boot-starter-parent?color=green&label=spring-boot&logo=spring-boot&style=for-the-badge)
![Docker Image Version (tag latest semver)](https://img.shields.io/docker/v/confluentinc/cp-kafka/7.5.0?color=green&label=confluent&logo=apache-kafka&logoColor=green&style=for-the-badge)

Complete implementation of Saga Pattern for distributed transactions across microservices using Spring Boot and Kafka.

## Features

- **Microservices Architecture**: Using `Spring Boot`, `Spring Cloud Gateway`, `Spring Cloud Stream`
- **Database per Service**: Each service has its own `PostgreSQL` database
- **Saga Pattern**: Distributed transaction orchestration across multiple services
- **Outbox Pattern**: Reliable event publishing using `Kafka`, `Debezium`, and `Kafka Connect`
- **Event-Driven**: Asynchronous communication via Kafka topics
- **Service Discovery**: Using `Consul` for service registration and discovery

![Banner](./assets/banner.jpg)

## Architecture Overview

The system consists of 4 microservices:
- **API Gateway** (Port 8080) - Routes requests to appropriate services
- **Order Service** (Port 9090) - Manages order lifecycle and saga orchestration
- **Customer Service** (Port 9091) - Handles customer management and balance updates
- **Inventory Service** (Port 9093) - Manages product inventory and stock updates

## Prerequisites

- **Java 17** or higher
- **Docker** and **Docker Compose**
- **Maven 3.6+**
- **Git**

## 🚀 Complete Setup Guide

### Step 1: Clone and Setup

```bash
# Clone the repository
git clone https://github.com....
cd saga-pattern-microservices

# Switch to Java 17 branch (if needed)
git checkout java17
```

### Step 2: Start Infrastructure Services

Start Docker containers (PostgreSQL, Kafka, Consul, Debezium):

#### For AMD64 systems:
```bash
export PLATFORM=linux/amd64
docker-compose up -d
```

#### For ARM64 systems (Apple Silicon):
```bash
export PLATFORM=linux/arm64
docker-compose up -d
```

Wait 2-3 minutes for all containers to start completely.

### Step 3: Verify Infrastructure

```bash
# Check all containers are running
docker ps

# Verify Consul is accessible
curl localhost:8500/v1/status/leader

# Verify Kafka is running
docker exec broker kafka-topics --bootstrap-server localhost:9092 --list
```

### Step 4: Build All Services

```bash
# Clean and build all microservices
mvn clean package -DskipTests=true
```

### Step 5: Start Microservices

**Important**: Start each service in a separate terminal window to monitor logs.

#### Terminal 1 - API Gateway:
```bash
mvn -f api-gateway/pom.xml spring-boot:run
```

#### Terminal 2 - Order Service:
```bash
mvn -f order-service/pom.xml spring-boot:run
```

#### Terminal 3 - Customer Service:
```bash
mvn -f customer-service/pom.xml spring-boot:run
```

#### Terminal 4 - Inventory Service:
```bash
mvn -f inventory-service/pom.xml spring-boot:run
```

### Step 6: Register Kafka Connectors

Wait for all services to start (check health endpoints), then register Debezium connectors:

```bash
# Register outbox pattern connectors
sh register-connectors.sh

# Verify connectors are running
curl localhost:8083/connectors
```

### Step 7: Verify Complete Setup

```bash
# Check all services are healthy
curl localhost:8080/actuator/health  # API Gateway
curl localhost:9090/actuator/health  # Order Service
curl localhost:9091/actuator/health  # Customer Service
curl localhost:9093/actuator/health  # Inventory Service

# Check service registration in Consul
curl localhost:8500/v1/catalog/services

# Check Kafka connectors status
curl localhost:8083/connectors/order_outbox_connector/status
curl localhost:8083/connectors/customer_outbox_connector/status
curl localhost:8083/connectors/inventory_outbox_connector/status
```

## 🧪 Testing the Saga Pattern

### Complete End-to-End Test

#### 1. Create a Customer
```bash
curl -X POST localhost:8080/customer-service/customers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "fullName": "John Doe",
    "balance": 5000.00
  }'
```
**Expected Response:**
```json
{
  "id": "customer-uuid-here",
  "username": "john_doe",
  "fullName": "John Doe",
  "balance": 5000.00
}
```

#### 2. Create a Product
```bash
curl -X POST localhost:8080/inventory-service/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Gaming Laptop",
    "stocks": 50
  }'
```
**Expected Response:**
```json
{
  "id": "product-uuid-here",
  "name": "Gaming Laptop",
  "stocks": 50
}
```

#### 3. Place an Order (Triggers Saga)
```bash
# Replace UUIDs with actual IDs from above responses
curl -X POST localhost:8080/order-service/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-uuid-here",
    "productId": "product-uuid-here",
    "quantity": 2,
    "price": 1500.00
  }'
```
**Expected Response:** HTTP 201 Created (no body)

#### 4. Verify Saga Completion
```bash
# Check customer balance (should be reduced by total price)
curl localhost:8080/customer-service/customers/customer-uuid-here

# Check product stock (should be reduced by quantity)
curl localhost:8080/inventory-service/products/product-uuid-here
```

**Expected Results:**
- Customer balance: `5000.00 - 1500.00 = 3500.00`
- Product stock: `50 - 2 = 48`

### Additional Test Scenarios

#### Test Saga Compensation (Insufficient Funds)
```bash
# Create customer with low balance
curl -X POST localhost:8080/customer-service/customers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "poor_customer",
    "fullName": "Poor Customer",
    "balance": 100.00
  }'

# Try to place expensive order (should fail and compensate)
curl -X POST localhost:8080/order-service/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "poor-customer-uuid",
    "productId": "existing-product-uuid",
    "quantity": 1,
    "price": 5000.00
  }'
```

#### Test Inventory Shortage
```bash
# Try to order more than available stock
curl -X POST localhost:8080/order-service/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "existing-customer-uuid",
    "productId": "existing-product-uuid",
    "quantity": 100,
    "price": 50.00
  }'
```

## 📊 Monitoring and Debugging

### Service Endpoints

| Service | Port | Health Check | Purpose |
|---------|------|--------------|---------|
| API Gateway | 8080 | `localhost:8080/actuator/health` | Request routing and load balancing |
| Order Service | 9090 | `localhost:9090/actuator/health` | Order management and saga orchestration |
| Customer Service | 9091 | `localhost:9091/actuator/health` | Customer and balance management |
| Inventory Service | 9093 | `localhost:9093/actuator/health` | Product and stock management |
| Consul | 8500 | `localhost:8500/ui` | Service discovery and configuration |
| Kafka Connect | 8083 | `localhost:8083/connectors` | Debezium connectors management |
| Control Center | 9021 | `localhost:9021` | Kafka cluster monitoring |

### Database Connections

| Database | Port | Connection |
|----------|------|------------|
| Order DB | 5432 | `postgresql://postgres:postgres@localhost:5432/postgres` |
| Customer DB | 5433 | `postgresql://postgres:postgres@localhost:5433/postgres` |
| Inventory DB | 5434 | `postgresql://postgres:postgres@localhost:5434/postgres` |

### Kafka Topics

Monitor Kafka topics to see event flow:
```bash
# List all topics
docker exec broker kafka-topics --bootstrap-server localhost:9092 --list

# Monitor ORDER events
docker exec broker kafka-console-consumer --bootstrap-server localhost:9092 --topic ORDER.events --from-beginning

# Monitor CUSTOMER events
docker exec broker kafka-console-consumer --bootstrap-server localhost:9092 --topic CUSTOMER.events --from-beginning

# Monitor PRODUCT events
docker exec broker kafka-console-consumer --bootstrap-server localhost:9092 --topic PRODUCT.events --from-beginning
```

## 🛠️ Troubleshooting

### Common Issues

1. **Port Conflicts**: Ensure ports 5432-5434, 8080, 8083, 8500, 9090-9093, 9021, 9092 are available
2. **Docker Issues**: Run `docker-compose down` and `docker-compose up -d` to restart
3. **Service Startup**: Wait for all Docker containers to be healthy before starting services
4. **Connector Issues**: Check `curl localhost:8083/connectors` and restart if needed

### Cleanup

```bash
# Stop all services (Ctrl+C in each terminal)

# Clean up connectors
sh delete-connectors.sh

# Stop Docker containers
docker-compose down

# Remove volumes (optional - will delete all data)
docker-compose down -v
```

## 🏗️ Development

### Project Structure
```
saga-pattern-microservices/
├── api-gateway/          # Spring Cloud Gateway
├── order-service/        # Order management + Saga orchestration
├── customer-service/     # Customer and balance management
├── inventory-service/    # Product and inventory management
├── docker-compose.yml    # Infrastructure services
└── *.json               # Debezium connector configurations
```

### Key Technologies
- **Spring Boot 3.5.4** - Microservice framework
- **Spring Cloud Gateway** - API Gateway and routing
- **Spring Cloud Stream** - Event-driven microservices
- **Kafka** - Event streaming platform
- **Debezium** - Change data capture
- **PostgreSQL** - Database per service
- **Consul** - Service discovery
- **Docker** - Containerization

## 📝 API Documentation

### Customer Service
- `POST /customers` - Create customer
- `GET /customers/{id}` - Get customer by ID

### Inventory Service
- `POST /products` - Create product
- `GET /products/{id}` - Get product by ID

### Order Service
- `POST /orders` - Place order (triggers saga)

All endpoints are accessible through the API Gateway at `localhost:8080/{service-name}/*`

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

Please make sure to update tests as appropriate.

## License

[MIT](./LICENSE)
