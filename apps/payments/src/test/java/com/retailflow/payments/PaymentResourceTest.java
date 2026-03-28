package com.retailflow.payments;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
class PaymentResourceTest {

    @Test
    void version_returnsV1ByDefault() {
        given()
            .when().get("/payments/version")
            .then()
            .statusCode(200)
            .body("version", equalTo("v1"));
    }

    @Test
    void processPayment_v1_alwaysApproved() {
        String body = """
                {
                  "orderId": "order-001",
                  "customerId": "customer-1",
                  "amount": 59.98
                }
                """;

        given()
            .contentType(ContentType.JSON)
            .body(body)
            .when().post("/payments")
            .then()
            .statusCode(201)
            .body("id", notNullValue())
            .body("orderId", equalTo("order-001"))
            .body("status", equalTo("APPROVED"))
            .body("provider", equalTo("stripe-mock"));
    }

    @Test
    void getPayment_byOrderId() {
        String orderId = "order-get-test";

        given()
            .contentType(ContentType.JSON)
            .body("{\"orderId\":\"" + orderId + "\",\"customerId\":\"c1\",\"amount\":10.00}")
            .when().post("/payments")
            .then()
            .statusCode(201);

        given()
            .when().get("/payments/" + orderId)
            .then()
            .statusCode(200)
            .body("orderId", equalTo(orderId));
    }

    @Test
    void getPayment_notFound_returns404() {
        given()
            .when().get("/payments/nonexistent-order")
            .then()
            .statusCode(404);
    }

    @Test
    void refund_approvedPayment_returnsRefunded() {
        int id = given()
            .contentType(ContentType.JSON)
            .body("{\"orderId\":\"order-refund\",\"customerId\":\"c1\",\"amount\":25.00}")
            .when().post("/payments")
            .then()
            .statusCode(201)
            .extract().path("id");

        given()
            .when().post("/payments/" + id + "/refund")
            .then()
            .statusCode(200)
            .body("status", equalTo("REFUNDED"));
    }

    @Test
    void refund_nonexistent_returns404() {
        given()
            .when().post("/payments/999999/refund")
            .then()
            .statusCode(404);
    }
}
