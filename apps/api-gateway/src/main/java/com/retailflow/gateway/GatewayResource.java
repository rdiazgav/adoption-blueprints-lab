package com.retailflow.gateway;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.rest.client.inject.RestClient;

import java.util.LinkedHashMap;
import java.util.Map;

@Path("/api")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
@ApplicationScoped
public class GatewayResource {

    @RestClient CatalogClient catalogClient;
    @RestClient OrdersClient ordersClient;
    @RestClient PaymentsClient paymentsClient;
    @RestClient RecommendationsClient recommendationsClient;

    // ------------------------------------------------------------------
    // Products → catalog service
    // ------------------------------------------------------------------

    @GET
    @Path("/products")
    public Response listProducts() {
        return forward(() -> catalogClient.listProducts());
    }

    @GET
    @Path("/products/{id}")
    public Response getProduct(@PathParam("id") Long id) {
        return forward(() -> catalogClient.getProduct(id));
    }

    // ------------------------------------------------------------------
    // Orders → orders service
    // ------------------------------------------------------------------

    @GET
    @Path("/orders")
    public Response listOrders(@QueryParam("customerId") String customerId) {
        return forward(() -> ordersClient.listOrders(customerId));
    }

    @GET
    @Path("/orders/{id}")
    public Response getOrder(@PathParam("id") Long id) {
        return forward(() -> ordersClient.getOrder(id));
    }

    @POST
    @Path("/orders")
    public Response createOrder(String body) {
        return forward(() -> ordersClient.createOrder(body));
    }

    // ------------------------------------------------------------------
    // Payments → payments service
    // ------------------------------------------------------------------

    @POST
    @Path("/payments")
    public Response processPayment(String body) {
        return forward(() -> paymentsClient.processPayment(body));
    }

    // ------------------------------------------------------------------
    // Recommendations → recommendations service
    // ------------------------------------------------------------------

    @GET
    @Path("/recommendations/{customerId}")
    public Response getRecommendations(@PathParam("customerId") String customerId) {
        return forward(() -> recommendationsClient.getRecommendations(customerId));
    }

    // ------------------------------------------------------------------
    // Aggregated health — calls each downstream liveness probe
    // ------------------------------------------------------------------

    @GET
    @Path("/health")
    public Response aggregatedHealth() {
        Map<String, String> services = new LinkedHashMap<>();
        boolean allUp = true;

        allUp &= probe("catalog",         services, () -> catalogClient.liveness());
        allUp &= probe("orders",          services, () -> ordersClient.liveness());
        allUp &= probe("payments",        services, () -> paymentsClient.liveness());
        allUp &= probe("recommendations", services, () -> recommendationsClient.liveness());

        String overall = allUp ? "UP" : "DOWN";
        Map<String, Object> body = Map.of("status", overall, "services", services);
        int status = allUp ? 200 : 207;
        return Response.status(status).entity(body).build();
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    // Forwards a downstream Response as-is; returns 502 on any exception.
    private Response forward(java.util.concurrent.Callable<Response> call) {
        try {
            return call.call();
        } catch (Exception e) {
            return Response.status(Response.Status.BAD_GATEWAY)
                    .entity(Map.of("error", "upstream error", "detail", e.getMessage()))
                    .build();
        }
    }

    // Calls a liveness probe, records UP/DOWN in the map, returns true if UP.
    private boolean probe(String name, Map<String, String> out,
                          java.util.concurrent.Callable<Response> call) {
        try {
            Response r = call.call();
            boolean up = r.getStatus() < 300;
            out.put(name, up ? "UP" : "DOWN");
            return up;
        } catch (Exception e) {
            out.put(name, "DOWN");
            return false;
        }
    }
}
