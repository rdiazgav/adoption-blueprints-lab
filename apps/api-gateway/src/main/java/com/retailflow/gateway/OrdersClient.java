package com.retailflow.gateway;

import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;

@RegisterRestClient(configKey = "orders")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public interface OrdersClient {

    @GET
    @Path("/orders")
    Response listOrders(@QueryParam("customerId") String customerId);

    @GET
    @Path("/orders/{id}")
    Response getOrder(@PathParam("id") Long id);

    @POST
    @Path("/orders")
    Response createOrder(String body);

    @GET
    @Path("/q/health/live")
    Response liveness();
}
