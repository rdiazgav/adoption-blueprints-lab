package com.retailflow.catalog;

import io.quarkus.test.junit.QuarkusTest;
import io.restassured.http.ContentType;
import org.junit.jupiter.api.Test;

import static io.restassured.RestAssured.given;
import static org.hamcrest.Matchers.*;

@QuarkusTest
class ProductResourceTest {

    @Test
    void listProducts_returnsArray() {
        given()
            .when().get("/products")
            .then()
            .statusCode(200)
            .contentType(ContentType.JSON)
            .body("$", isA(java.util.List.class));
    }

    @Test
    void createProduct_returnsCreatedProduct() {
        String body = """
                {
                  "name": "Wireless Mouse",
                  "description": "Ergonomic wireless mouse",
                  "category": "peripherals",
                  "price": 29.99,
                  "stock": 100
                }
                """;

        given()
            .contentType(ContentType.JSON)
            .body(body)
            .when().post("/products")
            .then()
            .statusCode(201)
            .body("id", notNullValue())
            .body("name", equalTo("Wireless Mouse"))
            .body("active", equalTo(true));
    }

    @Test
    void getProduct_notFound_returns404() {
        given()
            .when().get("/products/999999")
            .then()
            .statusCode(404);
    }

    @Test
    void updateProduct_changesFields() {
        int id = given()
            .contentType(ContentType.JSON)
            .body("""
                    {"name":"Keyboard","category":"peripherals","price":49.99,"stock":50}
                    """)
            .when().post("/products")
            .then()
            .statusCode(201)
            .extract().path("id");

        given()
            .contentType(ContentType.JSON)
            .body("""
                    {"name":"Mechanical Keyboard","category":"peripherals","price":79.99,"stock":40}
                    """)
            .when().put("/products/" + id)
            .then()
            .statusCode(200)
            .body("name", equalTo("Mechanical Keyboard"))
            .body("price", equalTo(79.99f));
    }

    @Test
    void deleteProduct_softDeletes() {
        int id = given()
            .contentType(ContentType.JSON)
            .body("""
                    {"name":"Monitor","category":"displays","price":299.00,"stock":20}
                    """)
            .when().post("/products")
            .then()
            .statusCode(201)
            .extract().path("id");

        given()
            .when().delete("/products/" + id)
            .then()
            .statusCode(204);

        given()
            .when().get("/products/" + id)
            .then()
            .statusCode(404);
    }

    @Test
    void listProducts_filterByCategory() {
        given()
            .contentType(ContentType.JSON)
            .body("""
                    {"name":"Headset","category":"audio","price":59.99,"stock":30}
                    """)
            .when().post("/products")
            .then()
            .statusCode(201);

        given()
            .queryParam("category", "audio")
            .when().get("/products")
            .then()
            .statusCode(200)
            .body("$", hasSize(greaterThanOrEqualTo(1)))
            .body("[0].category", equalTo("audio"));
    }
}
