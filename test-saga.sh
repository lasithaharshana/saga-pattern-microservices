#!/bin/bash

echo "🧪 SAGA PATTERN END-TO-END TEST"
echo "================================="

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to check service health
check_service() {
    local service_name=$1
    local port=$2
    
    echo -n "Checking ${service_name}... "
    
    if curl -s "localhost:${port}/actuator/health" > /dev/null; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Unhealthy${NC}"
        return 1
    fi
}

# Step 1: Check all services are running
echo -e "\n${BLUE}Step 1: Checking service health${NC}"
check_service "API Gateway" 8080
check_service "Order Service" 9090
check_service "Customer Service" 9091
check_service "Inventory Service" 9093

# Step 2: Create customer
echo -e "\n${BLUE}Step 2: Creating customer${NC}"
customer_response=$(curl -s -X POST localhost:8080/customer-service/customers \
  -H "Content-Type: application/json" \
  -d '{
    "username": "test_user",
    "fullName": "Test User",
    "balance": 5000.00
  }')

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Customer created:${NC}"
    echo "$customer_response" | jq '.'
    customer_id=$(echo "$customer_response" | jq -r '.id')
    echo -e "${YELLOW}Customer ID: $customer_id${NC}"
else
    echo -e "${RED}✗ Failed to create customer${NC}"
    exit 1
fi

# Step 3: Create product
echo -e "\n${BLUE}Step 3: Creating product${NC}"
product_response=$(curl -s -X POST localhost:8080/inventory-service/products \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Product",
    "stocks": 100
  }')

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Product created:${NC}"
    echo "$product_response" | jq '.'
    product_id=$(echo "$product_response" | jq -r '.id')
    echo -e "${YELLOW}Product ID: $product_id${NC}"
else
    echo -e "${RED}✗ Failed to create product${NC}"
    exit 1
fi

# Step 4: Place order
echo -e "\n${BLUE}Step 4: Placing order (triggering saga)${NC}"
order_response=$(curl -s -w "%{http_code}" -X POST localhost:8080/order-service/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"customerId\": \"$customer_id\",
    \"productId\": \"$product_id\",
    \"quantity\": 3,
    \"price\": 1500.00
  }")

http_code="${order_response: -3}"
if [[ "$http_code" == "201" ]]; then
    echo -e "${GREEN}✓ Order placed successfully (HTTP $http_code)${NC}"
    echo -e "${YELLOW}Waiting for saga to complete...${NC}"
    sleep 5
else
    echo -e "${RED}✗ Failed to place order (HTTP $http_code)${NC}"
    exit 1
fi

# Step 5: Verify saga results
echo -e "\n${BLUE}Step 5: Verifying saga results${NC}"

echo "Customer after order:"
customer_final=$(curl -s localhost:8080/customer-service/customers/$customer_id)
echo "$customer_final" | jq '.'

echo -e "\nProduct after order:"
product_final=$(curl -s localhost:8080/inventory-service/products/$product_id)
echo "$product_final" | jq '.'

# Extract and display changes
initial_balance=5000.00
initial_stock=100
final_balance=$(echo "$customer_final" | jq -r '.balance')
final_stock=$(echo "$product_final" | jq -r '.stocks')

echo -e "\n${BLUE}Saga Results Summary:${NC}"
echo -e "Customer Balance: $initial_balance → ${GREEN}$final_balance${NC} (paid 1500.00)"
echo -e "Product Stock: $initial_stock → ${GREEN}$final_stock${NC} (sold 3 items)"

# Verify calculations
expected_balance=3500.00
expected_stock=97

if [[ "$final_balance" == "$expected_balance" ]] && [[ "$final_stock" == "$expected_stock" ]]; then
    echo -e "\n${GREEN}🎉 SAGA PATTERN TEST PASSED! 🎉${NC}"
    echo -e "${GREEN}✓ Distributed transaction completed successfully${NC}"
    echo -e "${GREEN}✓ Customer balance updated correctly${NC}"
    echo -e "${GREEN}✓ Product stock updated correctly${NC}"
else
    echo -e "\n${RED}❌ SAGA PATTERN TEST FAILED!${NC}"
    echo -e "${RED}Expected: Balance=$expected_balance, Stock=$expected_stock${NC}"
    echo -e "${RED}Actual: Balance=$final_balance, Stock=$final_stock${NC}"
    exit 1
fi
