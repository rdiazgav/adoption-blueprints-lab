package com.retailflow.orders;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
class OrderResourceTest {

    @Test
    void listOrders_returnsArray() {
        given()
            .when().get("/orders")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("$", isA(java.util.List.class));
    }

    @Test
    void createOrder_returnsCreatedOrder() {
        String body = """
                {
                  "customerId": "customer-1",
                  "items": [
                    {
                      "productId": "prod-001",
                      "productName": "Wireless Mouse",
                      "quantity": 2,
                      "unitPrice": 29.99
                    }
                  ]
                }
                """;

        given()
            .contentType(ContentType.JSON)
            .body(body)
            .when().post("/orders")
            .then()
            .statusCode(201)
            .body("id", notNullValue())
            .body("customerId", equalTo("customer-1"))
            .body("status", equalTo("PENDING"))
            .body("items", hasSize(1));
    }

    @Test
    void getOrder_notFound_returns404() {
        given()
            .when().get("/orders/999999")
            .then()
            .statusCode(404);
    }

    @Test
    void updateStatus_changesOrderStatus() {
        String createBody = """
                {
                  "customerId": "customer-2",
                  "items": [{"productId": "p1", "productName": "Keyboard", "quantity": 1, "unitPrice": 99.00}]
                }
                """;

        int id = given()
            .contentType(ContentType.JSON)
            .body(createBody)
            .when().post("/orders")
            .then()
            .statusCode(201)
            .extract().path("id");

        given()
            .contentType(ContentType.JSON)
            .body("{\"status\": \"CONFIRMED\"}")
            .when().patch("/orders/" + id + "/status")
            .then()
            .statusCode(200)
            .body("status", equalTo("CONFIRMED"));
    }

    @Test
    void listOrders_filterByCustomerId() {
        String body = """
                {
                  "customerId": "unique-customer-xyz",
                  "items": [{"productId": "p2", "productName": "Monitor", "quantity": 1, "unitPrice": 299.00}]
                }
                """;

        given()
            .contentType(ContentType.JSON)
            .body(body)
            .when().post("/orders")
            .then()
            .statusCode(201);

        given()
            .queryParam("customerId", "unique-customer-xyz")
            .when().get("/orders")
            .then()
            .statusCode(200)
            .body("$", hasSize(greaterThanOrEqualTo(1)))
            .body("[0].customerId", equalTo("unique-customer-xyz"));
    }
}
